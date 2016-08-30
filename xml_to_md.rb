require 'nokogiri'

class NodeParser
  def initialize(node)
    return if node.name == 'text'
    method_name = node.name.to_sym

    if self.respond_to?(method_name)
      self.send(method_name, )
    end

    node.children.each do |child|
      parse_node(child)
    end
  end

  def self.text


  def preface(node, &children)
    @preface = NodeParser.text(node)
  end
end

xml = File.open('mcm_5_jun_2016.xml') { |f| Nokogiri::XML(f) }
NodeParser.new(xml.root)
