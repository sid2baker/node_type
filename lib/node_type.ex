defmodule NodeType do
  @moduledoc ~S'''

  '''

  @doc """
  """
  @callback setup(node :: map()) :: {:ok, map()}

  @doc """
  """
  @callback subscribe(node_id :: String.t()) :: :ok

  defmacro __using__(opts) do
    quote location: :keep, bind_quoted: [opts: opts] do
      @behaviour NodeType

      use GenServer

      import NodeType, only: [template: 1, javascript: 1, help_text: 1]

      @before_compile NodeType

      @node_type_opts opts

      Module.register_attribute(__MODULE__, :inline_template, [])
      Module.register_attribute(__MODULE__, :inline_javascript, [])
      Module.register_attribute(__MODULE__, :inline_help_text, [])
    end
  end

  defmacro template(do: block) do
    quote bind_quoted: [content: block] do
      Module.put_attribute(__MODULE__, :inline_template, content)
    end
  end

  defmacro javascript(do: block) do
    quote bind_quoted: [content: block] do
      Module.put_attribute(__MODULE__, :inline_javascript, content)
    end
  end

  defmacro help_text(do: block) do
    quote bind_quoted: [content: block] do
      Module.put_attribute(__MODULE__, :inline_help_text, content)
    end
  end

  defmacro __before_compile__(env) do
    opts = Module.get_attribute(env.module, :node_type_opts)
    node_name = opts[:name] || __to_node_name__(__MODULE__)
    asset_path = opts[:asset_path]

    template =
      case Module.get_attribute(env.module, :inline_template) do
        nil ->
          EEx.eval_file(Path.join([asset_path, "template.html.eex"]))

        inline_template ->
          inline_template
      end

    javascript =
      case Module.get_attribute(env.module, :inline_javascript) do
        nil ->
          EEx.eval_file(Path.join([asset_path, "node.js.eex"]))

        inline_javascript ->
          inline_javascript
      end

    help_text =
      case Module.get_attribute(env.module, :inline_help_text) do
        nil ->
          EEx.eval_file(Path.join([asset_path, "help.html.eex"]))

        inline_help_text ->
          inline_help_text
      end

    node_definition =
      """
      <script type="text/javascript">
      {
        #{javascript}
        RED.nodes.registerType("#{node_name}", node);
      }
      </script>
      <script type="text/html" data-template-name="#{node_name}">
      #{template}
      </script>
      <script type="text/html" data-help-name="#{node_name}">
      #{help_text}
      </script>
      """

    quote do
      def start_link(node) do
        GenServer.start_link(__MODULE__, node, name: via_tuple(node.id))
      end

      def init(node) do
        :ok = subscribe(node.id)
        setup(node)
      end

      defp via_tuple(id), do: {:via, Registry, {NodeEx.Runtime.Registry, id}}

      def __node_definition__() do
        unquote(node_definition)
      end

      def __mix_recompile__?() do
        true
      end
    end
  end

  defp __to_node_name__(module) do
    module
    |> Module.split()
    |> List.last()
    |> Macro.underscore()
    |> String.replace("_", "-")
  end
end
