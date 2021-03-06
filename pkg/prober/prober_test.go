package prober

import (
	"context"
	"fmt"
	"net"
	"net/http"
	"path"
	"testing"

	"github.com/go-kit/kit/log"
	"github.com/oklog/run"
	"github.com/thanos-io/thanos/pkg/testutil"
)

func doGet(ctx context.Context, url string) (*http.Response, error) {
	req, err := http.NewRequest("GET", fmt.Sprintf("http://%s", url), nil)
	if err != nil {
		return nil, err
	}

	return http.DefaultClient.Do(req.WithContext(ctx))
}

type TestComponent struct {
	name string
}

func (c TestComponent) String() string {
	return c.name
}

func TestProberHealthInitialState(t *testing.T) {
	p := New(TestComponent{name: "test"}, log.NewNopLogger(), nil)

	testutil.Assert(t, !p.isHealthy(), "initially should not be healthy")
}

func TestProberReadinessInitialState(t *testing.T) {
	p := New(TestComponent{name: "test"}, log.NewNopLogger(), nil)

	testutil.Assert(t, !p.isReady(), "initially should not be ready")
}

func TestProberHealthyStatusSetting(t *testing.T) {
	testError := fmt.Errorf("test error")
	p := New(TestComponent{name: "test"}, log.NewNopLogger(), nil)

	p.Healthy()

	testutil.Assert(t, p.isHealthy(), "should be healthy")

	p.NotHealthy(testError)

	testutil.Assert(t, !p.isHealthy(), "should not be healthy")
}

func TestProberReadyStatusSetting(t *testing.T) {
	testError := fmt.Errorf("test error")
	p := New(TestComponent{name: "test"}, log.NewNopLogger(), nil)

	p.Ready()

	testutil.Assert(t, p.isReady(), "should be ready")

	p.NotReady(testError)

	testutil.Assert(t, !p.isReady(), "should not be ready")
}

func TestProberMuxRegistering(t *testing.T) {
	serverAddress := fmt.Sprintf("localhost:%d", 8081)

	l, err := net.Listen("tcp", serverAddress)
	testutil.Ok(t, err)

	p := New(TestComponent{name: "test"}, log.NewNopLogger(), nil)

	healthyEndpointPath := "/-/healthy"
	readyEndpointPath := "/-/ready"

	mux := http.NewServeMux()
	mux.HandleFunc(healthyEndpointPath, p.HealthyHandler())
	mux.HandleFunc(readyEndpointPath, p.ReadyHandler())

	var g run.Group
	g.Add(func() error {
		return fmt.Errorf("serve probes %w", http.Serve(l, mux))
	}, func(err error) {
		t.Fatalf("server failed: %v", err)
	})

	go func() { _ = g.Run() }()

	{
		ctx, cancel := context.WithCancel(context.Background())
		defer cancel()

		resp, err := doGet(ctx, path.Join(serverAddress, healthyEndpointPath))
		testutil.Ok(t, err)
		defer resp.Body.Close()

		testutil.Equals(t, resp.StatusCode, http.StatusServiceUnavailable, "should not be healthy, response code: %d", resp.StatusCode)
	}
	{
		ctx, cancel := context.WithCancel(context.Background())
		defer cancel()

		resp, err := doGet(ctx, path.Join(serverAddress, readyEndpointPath))
		testutil.Ok(t, err)
		defer resp.Body.Close()

		testutil.Equals(t, resp.StatusCode, http.StatusServiceUnavailable, "should not be ready, response code: %d", resp.StatusCode)
	}
	{
		p.Healthy()

		ctx, cancel := context.WithCancel(context.Background())
		defer cancel()

		resp, err := doGet(ctx, path.Join(serverAddress, healthyEndpointPath))
		testutil.Ok(t, err)
		defer resp.Body.Close()

		testutil.Equals(t, resp.StatusCode, http.StatusOK, "should be healthy, response code: %d", resp.StatusCode)
	}
	{
		p.Ready()

		ctx, cancel := context.WithCancel(context.Background())
		defer cancel()

		resp, err := doGet(ctx, path.Join(serverAddress, readyEndpointPath))
		testutil.Ok(t, err)
		defer resp.Body.Close()

		testutil.Equals(t, resp.StatusCode, http.StatusOK, "should be ready, response code: %d", resp.StatusCode)
	}
}
