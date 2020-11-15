module Seafoam
  module Annotators
    class ScaleAnnotator < Annotator
      def self.applies?(graph)
        true
      end

      def annotate(graph)
        name_widely_used_nodes graph
      end

      private

      def name_widely_used_nodes(graph)
        graph.nodes.values.dup.each do |node|
          next if node.props[:inlined] || node.props[:hidden]

          visible_outputs = node.outputs.reject { |output| output.props[:inlined] || output.props[:hidden] || output.props[:kind] == 'control' || output.to.props[:hidden] }
          
          if visible_outputs.map(&:to).uniq.size > 10
            p node.id

            use = graph.create_node nil, node.props.dup
            use.props[:inlined] = true
            use.props[:label] = "valueof(#{node.id})"
            
            visible_outputs.each do |output|
              graph.create_edge use, output.to, output.props.dup
              output.props[:hidden] = true
            end

            assign = graph.create_node(nil, { kind: 'info', label: "#{visible_outputs.size} users of #{node.id}" })
            graph.create_edge node, assign, { kind: 'data' }
          end
        end
      end
    end
  end
end
