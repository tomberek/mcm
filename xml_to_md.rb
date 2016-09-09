require 'nokogiri'
require 'byebug'

class Nokogiri::XML::Node
  TEXT_CLEANERS = [
    [/\n|\r/, ''],
    [/(<line>\s*)+/, "\n\n"], ['</line>', ''],
    ['&emsp;', ' '],
    ['&bull;', '-'],
    ['&ldquo;', '"'], ['&rdquo;', '"']
  ]

  def clean_text
    content = self.inner_html

    TEXT_CLEANERS.each do |mapping|
      content.gsub!(mapping[0], mapping[1])
    end

    content
  end
end

module NodeTypes
  def preface(node, &block)
    @parts[:preface] = yield
  end

  def paratext(node, &block)
    content = yield
    node.clean_text
  end

  def sigblock(node)
    "\n\n#{node.clean_text}"
  end
end

class NodeParser
  include NodeTypes

  def initialize(doc)
    @doc = doc
    @root_node = doc.root
    @parts = {}

    parse_node(@root_node)
  end

  def parse_node(node)
    method_name = node.name.to_sym
    if NodeTypes.method_defined?(method_name)
      self.send(method_name, node) do
        node.children.collect do |child|
          result = parse_node(child)
          if result.is_a?(String)
            child.remove
          end
          result
        end
      end
    else
      node.children.collect do |child|
        parse_node(child)
      end
    end
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
