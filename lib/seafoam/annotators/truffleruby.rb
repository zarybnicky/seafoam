module Seafoam
  module Annotators
    class TruffleRubyAnnotator < Annotator
      def self.applies?(graph)
        graph.nodes.values.any? { |n| blackhole?(n) }
      end

      def annotate(graph)
        blackholes graph
      end

      private

      def blackholes(graph)
        graph.nodes.each_value do |node|
          if TruffleRubyAnnotator.blackhole?(node)
            node.props[:blackhole] = true
          end
        end
      end

      def self.blackhole?(node)
        node.props.dig(:node_class, :node_class) == 'org.graalvm.compiler.nodes.java.StoreFieldNode' &&
          node.props.dig('field', :field_class) == 'org.truffleruby.extra.TruffleGraalNodes$BlackholeNode'
      end
    end
  end
end
