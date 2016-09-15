require 'nokogiri'
require 'byebug'

TEXT_CLEANERS = [
  [/\n|\r/, ''],
  [/(<line>\s*)+(&emsp;\s*){0,2}/, "\n\n"], ['</line>', ''],
  ['&emsp;', ' '],
  ['&bull;', '-'],
  ['&ldquo;', '"'], ['&rdquo;', '"']
]

def clean_node(node)
  clean_text node.text? ? node.inner_text : node.inner_html
end

def clean_text(content)
  TEXT_CLEANERS.each do |mapping|
    content.gsub! mapping[0], mapping[1]
  end

  content
end

module NodeTypes
  def preface(node, &block)
    @parts[:preface] = yield
  end

  def paratext(node, &block)
    yield
  end

  def line(node, &block)
    if node.next_element&.name == 'line'
      ''
    else
      "\n\n#{yield}"
    end
  end

  def sigblock(node)
    "\n\n#{clean_node node}"
  end

  def italic(node, &block)
    "_#{yield}_"
  end

  def change(node, &block)
    "___#{yield}___"
  end

  def text(node)
    clean_node node
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
      # byebug unless node.text?
      self.send(method_name, node) do
        node.children.collect do |child|
          parse_node(child)
        end.join('')
      end
    else
      node.children.collect do |child|
        parse_node(child)
      end.join('')
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
