module Seafoam
  module Annotators
    # The Truffle annotator applies if it looks like it was compiled by Truffle.
    class TruffleAnnotator < Annotator
      def self.applies?(graph)
        graph.props.values.any? do |v|
          TRIGGERS.any? { |t| v.to_s.include?(t) }
        end
      end

      def annotate(graph)
        hide_pi graph
        truffle_arguments graph
        #hide_begin graph
        hide_alloc_constants graph
      end

      private

      def hide_pi(graph)
        graph.nodes.each_value do |node|
          if ['org.graalvm.compiler.nodes.PiNode', 'org.graalvm.compiler.nodes.PiArrayNode'].include?(node.props.dig(:node_class, :node_class))
            node.outputs.each do |output|
              node.inputs.each do |input|
                if input.props[:label] == 'object'
                  graph.create_edge input.from, output.to, output.props
                end
              end
            end
            
            node.props[:hidden] = true
          end
        end
      end

      def truffle_arguments(graph)
        graph.nodes.each_value do |node|
          if node.props.dig(:node_class, :node_class) == 'org.graalvm.compiler.nodes.java.LoadIndexedNode'
            if node.inputs.any? { |input| input.props[:kind] == 'data' && input.props[:label] == 'array' && effectively_p1?(input.from) }
              index_edge = node.inputs.find { |input| input.props[:kind] == 'data' && input.props[:label] == 'index' }
              if index_edge && index_edge.from.props.dig(:node_class, :node_class) == 'org.graalvm.compiler.nodes.ConstantNode'
                index = index_edge.from.props['rawvalue']
                node.props[:label] = "T(#{index})"
                node.props[:truffle_argument] = index
              end
            end
          end
        end

        start_node = graph.nodes.values.find { |node| node.props.dig(:node_class, :node_class) == 'org.graalvm.compiler.nodes.StartNode' }

        chain = start_node
        arg_loads = []
        loop do
          chain = chain.outputs.find { |input| input.props[:kind] == 'control' }.to
          break unless chain.props[:truffle_argument]
          
          chain.props[:hidden] = true
          shadow = graph.create_node(chain.id, { label: chain.props[:label], inlined: true, kind: 'input' })
          
          chain.outputs.each do |output|
            if output.props[:kind] == 'data'
              graph.create_edge shadow, output.to, output.props
            end
          end

          arg_loads.push chain
        end

        unless arg_loads.empty?
          argument_load = graph.create_node(nil, { label: 'Load T(...)', kind: 'effect' })
          graph.create_edge arg_loads.first.inputs.find { |edge| edge.props[:label] == 'array' && !edge.from.props[:hidden] }.from, argument_load, { kind: 'data', label: 'array' }
          graph.create_edge start_node, argument_load, { kind: 'control' }
          graph.create_edge argument_load, chain, { kind: 'control' }
        end

        # graph.nodes.values.dup.each do |node|
        #   if node.props.dig(:node_class, :node_class) == 'org.graalvm.compiler.nodes.extended.UnboxNode'
        #     p node.inputs
        #     t = node.inputs.find { |input| input.from.props[:truffle_argument] }
        #     if t
        #       t = t.from
        #       t_unbox = graph.create_node(nil, {label: "unbox(#{t.id} #{t.props[:truffle_argument]})", kind: 'input', inlined: true})
        #       node.outputs.each do |output|
        #         output.to.inputs.each do |input|
        #           if input.props[:kind] == 'data' && input.from == node
        #             graph.create_edge t_unbox, output.to, input.props
        #             node.props[:hidden] = true
        #           end
        #         end
        #       end

        #       before = node.inputs.find { |input| input.props[:kind] == 'control' && !input.props[:hidden] && !input.from.props[:hidden] }
        #       after = node.outputs.find { |output| output.props[:kind] == 'control' && !output.props[:hidden] && !output.to.props[:hidden] }
        #       graph.create_edge before.from, after.to, before.props.dup
        #       before.props[:hidden] = true
        #       after.props[:hidden] = true
        #     end
        #   end
        # end
      end

      def effectively_p1?(node)
        case node.props.dig(:node_class, :node_class)
        when 'org.graalvm.compiler.nodes.ParameterNode'
          node.props['index'] == 1
        when 'org.graalvm.compiler.nodes.PiNode', 'org.graalvm.compiler.nodes.PiArrayNode'
          object_edge = node.inputs.find { |input| input.props[:kind] == 'data' && input.props[:label] == 'object' }
          effectively_p1?(object_edge.from)
        else
          false
        end
      end

      def hide_begin(graph)
        graph.nodes.each_value do |node|
          if ['org.graalvm.compiler.nodes.BeginNode', 'org.graalvm.compiler.nodes.KillingBeginNode'].include?(node.props.dig(:node_class, :node_class))
            input = node.inputs.find { |input| !input.from.props[:hidden] }
            output = node.outputs.find { |output| !output.to.props[:hidden] }
            graph.create_edge input.from, output.to, input.props
            node.props[:hidden] = true
          end
        end
      end

      def hide_alloc_constants(graph)
        graph.nodes.each_value do |node|
          if node.props.dig(:node_class, :node_class) == 'org.graalvm.compiler.nodes.virtual.CommitAllocationNode'
            node.inputs.each do |input|
              if input.from.props.dig(:node_class, :node_class) == 'org.graalvm.compiler.nodes.ConstantNode'
                input.props[:hidden] = true
              end
            end
          end
        end
      end

      # If we see these in the graph properties it's probably a Truffle graph.
      TRIGGERS = %w[
        TruffleCompilerThread
      ]
    end
  end
end
