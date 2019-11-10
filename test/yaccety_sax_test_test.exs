defmodule YaccetySaxTestTest do
  use ExUnit.Case
  doctest YaccetySaxTest

  setup do
    input =
      """
      <tag>
      <subtag>asdf</subtag>
      <subtag>qwer</subtag>
      <subtag>asdf</subtag>
      </tag>
      """
      |> String.trim()

    {:ok, input: input}
  end

  test "replaces values", %{input: input} do
    state = :stax.stream(input, [{:whitespace, false}])

    # fake it for now until there is a serialization API
    outState = {"", %{}}

    # read and assert the startDocument event, write it out
    {%{type: :startDocument} = e1, state1} = :stax.next_event(state)
    outState1 = :stax.write_event(e1, outState)

    # read and assert the startElement event for the "tag" tag, write it out
    {%{type: :startElement, qname: {"", "", "tag"}} = e2, state2} = :stax.next_event(state1)
    outState2 = :stax.write_event(e2, outState1)

    {state3, outState3} = reverse_subtag(state2, outState2)
    {state4, outState4} = reverse_subtag(state3, outState3)
    {state5, outState5} = reverse_subtag(state4, outState4)

    # read and assert the endElement event for the "tag" tag, write it out
    {%{type: :endElement, qname: {"", "", "tag"}} = e3, state6} = :stax.next_event(state5)
    outState6 = :stax.write_event(e3, outState5)

    # read and assert the endDocument event, write it out
    {%{type: :endDocument} = e4, _} = :stax.next_event(state6)
    {output, _} = :stax.write_event(e4, outState6)

    IO.inspect(output)
  end

  defp reverse_subtag(state, outState) do
    case :stax.next_event(state) do
      # the 'subtag' opening tag
      {%{type: :startElement} = e1, state1} ->
        outState1 = :stax.write_event(e1, outState)
        reverse_subtag(state1, outState1)

      # the text to change
      {%{type: :characters, data: text} = e1, state1} ->
        outState1 = :stax.write_event(%{e1 | data: String.reverse(text)}, outState)
        reverse_subtag(state1, outState1)

      # subtag closing tag, so return
      {%{type: :endElement} = e1, state1} ->
        outState1 = :stax.write_event(e1, outState)
        {state1, outState1}
    end
  end

  test "read and write without transforms", %{input: input} do
    stream = stream(input, [{:whitespace, false}])
    {output, _} = Enum.reduce(stream, {"", %{}}, &:stax.write_event/2)
    IO.inspect(output)
  end

  test "transform stream", %{input: input} do
    stream = stream(input, [{:whitespace, false}])
    {output, _} = Enum.reduce(stream, {"", %{}}, &transform/2)
    IO.inspect(output)
  end

  defp transform(%{type: :startElement, qname: {"", "", "subtag"}} = event, outState) do
    {:inside_subtag, :stax.write_event(event, outState)}
  end

  defp transform(%{type: :characters, data: data} = event, {:inside_subtag, outState}) do
    :stax.write_event(%{event | data: String.reverse(data)}, outState)
  end

  defp transform(event, outState) do
    :stax.write_event(event, outState)
  end

  defp stream(input, opts) do
    Stream.unfold(
      :stax.stream(input, opts),
      fn
        # clause to stop the stream because there are no more events
        {_, %{position: [:misc_post_element]}} ->
          nil

        # recursive clause should return {next_stream_element, new_stream_state}
        state ->
          :stax.next_event(state)
      end
    )
  end
end
