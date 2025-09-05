module ActiveRecordRules
  class Graph
    def initialize(parent = nil)
      @parent = parent
      @vertices = {}
      @edges = Hash.new { _1[_2] = {} }
    end

    def vertex(key)
      @vertices[key] || @parent&.vertex(key)
    end

    def vertex?(key)
      @vertices.key?(key) || @parent&.vertex?(key)
    end

    def add_vertex(key, value = key)
      raise "Duplicate vertex: #{key}" if vertex?(key)

      @vertices[key] = value
    end

    # Return hash of edges from left, which is the left portion of an
    # edge.
    def edges(left)
      { **@edges[left], **(@parent&.edges(left) || {}) }
    end

    def edge?(left, right)
      (@edges.key?(left) && @edges[left].key?(right)) || @parent&.edge?(left, right)
    end

    def add_edge(left, right, value = [ left, right ])
      raise "Duplicate edge: #{left} -> #{right}" if edge?(left, right)

      @edges[left][right] = value
    end

    # Find all paths starting from sources and going to sinks.
    #
    # The path will be returned as interleaved table and edge values.
    # For each path, the first element will be the value for one of
    # the keys in sources, and the last element will be the value for
    # one of the keys in sinks.
    #
    #
    def find_paths(sources, sinks)
      to_do = sources.map { [ _1, [ vertex(_1) ] ] }
      paths = []
      seen = Set.new

      while (key, path = to_do.shift)
        if sinks.include?(key)
          paths << path
        elsif seen.add?(key)
          to_do += edges(key).map { [ _1, path + [ _2, vertex(_1) ] ] }
        end
      end

      paths
    end
  end
end
