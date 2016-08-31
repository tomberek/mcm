require 'nokogiri'
require 'byebug'

module NodeTypes
  REPLACEMENTS = [
    [/\n|\r/, ''],
    [/(\<line\>\s*)+/, "\n\n"], ['</line>', ''],
    ['&emsp;', ' '],
    ['&bull;', '-'],
    ['&ldquo;', '"'], ['&rdquo;', '"']
  ]

  def preface(node)
    content = collect_children(node)
    @parts[:preface] = content
    return content
  end

  def paratext(node)
    content = node.inner_html
    REPLACEMENTS.each do |mapping|
      content = content.gsub(mapping[0], mapping[1])
    end
    return content
  end
end

class NodeParser
  include NodeTypes

  NODE_REPLACEMENTS = [
    ['bold', '**'],
    ['italic', '_']
  ]

  def initialize(doc)
    @doc = doc
    @root_node = doc.root
    @parts = {}

    NODE_REPLACEMENTS.each do |mapping|
      @doc.xpath("//#{mapping[0]}").each do |node|
        node.replace(mapping[1] + node.inner_html + mapping[1])
      end
    end

    parse_node(@root_node)
  end

  def parse_node(node)
    method_name = node.name.to_sym
    if NodeTypes.method_defined?(method_name)
      result = self.send(method_name, node)
      return result if result
    end

    node.element_children.each do |child|
      parse_node(child)
    end

    return
  end

  def collect_children(node)
    result = []
    node.children.each do |child|
      result << parse_node(child)
    end
    result.compact.join('')
  end

  def output
    @parts.each do |key, value|
      File.open("manual/#{key}.md", 'w') { |file| file.write(value) }
    end
  end
end

xml = File.open('mcm_5_jun_2016.xml') { |f| Nokogiri::HTML(f) { |config| config.nonet.noent } }
parser = NodeParser.new(xml)
parser.output
