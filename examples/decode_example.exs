# Decoding example
#
# The following pipeline takes a G.711 A-law file and decodes it to the raw audio.

Logger.configure(level: :info)

Mix.install([
  {:membrane_g711_plugin, path: __DIR__ |> Path.join("..") |> Path.expand(), override: true},
  :membrane_file_plugin,
  :req
])

sample_url =
  "https://raw.githubusercontent.com/membraneframework/static/gh-pages/samples/beep-alaw-8kHz-mono.raw"

sample_path = Path.join(System.tmp_dir!(), "beep-alaw-8kHz-mono.raw")

unless File.exists?(sample_path) do
  response = Req.get!(sample_url)
  File.write!(sample_path, response.body)
end

defmodule Decoding.Pipeline do
  use Membrane.Pipeline

  @impl true
  def handle_init(_ctx, sample_path) do
    spec =
      child(:source, %Membrane.File.Source{location: sample_path})
      |> child(:decoder, Membrane.G711.Decoder)
      |> child(:sink, %Membrane.File.Sink{location: "output.raw"})

    {[spec: spec], %{}}
  end

  @impl true
  def handle_element_end_of_stream(:sink, _pad, _ctx, state) do
    {[terminate: :shutdown], state}
  end

  @impl true
  def handle_element_end_of_stream(_child, _pad, _ctx, state) do
    {[], state}
  end
end

# Start and monitor the pipeline
{:ok, _supervisor_pid, pipeline_pid} =
  Membrane.Pipeline.start_link(Decoding.Pipeline, sample_path)

ref = Process.monitor(pipeline_pid)

# Wait for the pipeline to finish
receive do
  {:DOWN, ^ref, :process, _pipeline_pid, reason} ->
    if reason in [:shutdown, :normal] do
      IO.puts("Pipeline finished: #{inspect(reason)}")
      System.halt(0)
    else
      IO.puts(:stderr, "Pipeline failed: #{inspect(reason)}")
      System.halt(1)
    end
end
