defmodule Chord.Delta.Formatter.Default do
  @moduledoc """
  Default implementation for delta formatting in Chord.

  This module transforms delta maps into a standardized format that is easy to process,
  serialize, and consume. Each change is flattened into a list of maps, providing details such as
  the action performed (`:added`, `:modified`, `:removed`), the affected key path, and associated metadata
  like `context_id`.

  ## Customization

  Developers can implement their own delta formatter by defining a module that adheres to
  the `Chord.Delta.Formatter.Behaviour` and setting it in the application configuration.

      defmodule MyApp.CustomFormatter do
        @behaviour Chord.Delta.Formatter.Behaviour

        def format(delta, metadata) do
          # Custom formatting logic here
        end
      end

  To configure your formatter:

      config :chord, delta_formatter: MyApp.CustomFormatter
  """

  @behaviour Chord.Delta.Formatter.Behaviour

  @doc """
  Formats a delta map into a standardized format with metadata.

  This function processes deltas, flattening key paths into lists and associating
  each change with additional metadata such as `context_id`.

  ## Parameters
    - `delta` (map): The delta map representing changes to the context.
    - `metadata` (map): A keyword list or map containing additional information, such as:
      - `:context_id` - The identifier of the context.
      - `:version` - The version of the context being formatted.

  ## Returns
    - A map with the following structure:
      - `:version` - The version number provided in `metadata` (optional).
      - `:changes` - A list of formatted changes, each represented as a map.

  ## Examples
      iex> delta = %{
      ...>   status: %{action: :added, value: "online"},
      ...>   metadata: %{
      ...>     language: %{action: :added, value: "en-US"},
      ...>     theme: %{action: :modified, old_value: "light", value: "dark"}
      ...>   }
      ...> }
      iex> metadata = %{context_id: "user:369", version: 2}
      iex> Chord.Delta.Formatter.Default.format(delta, metadata)
      %{
        version: 2,
        changes: [
          %{value: "online", key: :status, action: :added, context_id: "user:369"},
          %{
            value: "en-US",
            key: [:metadata, :language],
            action: :added,
            context_id: "user:369"
          },
          %{
            value: "dark",
            key: [:metadata, :theme],
            action: :modified,
            context_id: "user:369",
            old_value: "light"
          }
        ]
      }
  """
  @spec format(map(), any()) :: map()
  @impl true
  def format(delta, metadata \\ %{}) do
    version = Map.get(metadata, :version)
    context_id = Map.get(metadata, :context_id)

    formatted_changes =
      Enum.flat_map(delta, fn {key, change} ->
        format_change(key, change, context_id)
      end)

    %{
      version: version,
      changes: formatted_changes
    }
  end

  defp format_change(key, change, context_id)
       when is_map(change) and not is_map_key(change, :action) do
    Enum.flat_map(change, fn {nested_key, nested_change} ->
      nested_path = [key | List.wrap(nested_key)]
      format_change(nested_path, nested_change, context_id)
    end)
  end

  defp format_change(key_path, %{action: :added, value: value}, context_id) do
    [%{key: key_path, action: :added, value: value, context_id: context_id}]
  end

  defp format_change(
         key_path,
         %{action: :modified, old_value: old_value, value: value},
         context_id
       ) do
    [
      %{
        key: key_path,
        action: :modified,
        old_value: old_value,
        value: value,
        context_id: context_id
      }
    ]
  end

  defp format_change(key_path, %{action: :removed, old_value: old_value}, context_id) do
    [%{key: key_path, action: :removed, old_value: old_value, value: nil, context_id: context_id}]
  end
end
