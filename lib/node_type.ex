defmodule NodeType do
  @moduledoc ~S'''

  '''

  @doc """
  """
  @callback setup(node :: map()) :: {:ok, map()}

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
    asset_path = opts[:asset_path]

    inline_template = Module.get_attribute(env.module, :inline_template)
    inline_javascript = Module.get_attribute(env.module, :inline_javascript)
    inline_help_text = Module.get_attribute(env.module, :inline_help_text)

    node_definition =
      if asset_path do
        File.read!(asset_path)
      else
        module_name = __to_node_name__(__MODULE__)

        """
        <script type="text/javascript">
        RED.nodes.registerType("#{module_name}",
        #{inline_javascript}
        );
        </script>
        <script type="text/html" data-template-name="#{module_name}">
        #{inline_template}
        </script>
        <script type="text/html" data-help-name="#{module_name}">
        #{inline_help_text}
        </script>
        """
      end

    quote do
      def start_link(node) do
        GenServer.start_link(__MODULE__, node, name: via_tuple(node.id))
      end

      def init(node) do
        :ok = NodeEx.MQTT.Server.subscribe(["notification/node/#{node.id}"])
        setup(node)
      end

      defp via_tuple(id), do: {:via, Registry, {NodeEx.Runtime.Registry, id}}

      def __node_definition__() do
        unquote(node_definition)
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
