require 'nokogiri'
require 'byebug'

TEXT_CLEANERS = [
  [/\n|\r/, ''],
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
end

module SAXOpenNodes
  def preface(name, attrs)
    @parts[:preface] = @output = []
  end

  def line(name, attrs)
    @output << '\n\n' unless @output.last == '\n\n'
  end
end

class MCMDoc < Nokogiri::XML::SAX::Document
  attr_reader :output
  attr_reader :parts

  def initialize
    super
    @output = []
    @parts = {}
  end

  def start_element(name, attrs=[])
    method_name = name.downcase.to_sym
    if SAXOpenNodes.method_defined?(method_name)
      SAXOpenNodes.send(method_name, name, attrs)
    end
  end

  def end_element(name, attrs=[])
    # puts "ending: #{name}"
  end

  def characters(string)
    @output << clean_text(string)
  end
  #
  # def error string
  #   puts "ERROR #{string}"
  # end

  def output
    @parts.each do |key, value|
      File.open("manual/#{key}.md", 'w') { |file| file.write(value) }
    end
  end
end

document = MCMDoc.new
parser = Nokogiri::XML::SAX::Parser.new(document)
File.open('mcm_5_jun_2016.xml') { |f| parser.parse(f) { |ctx| ctx.recovery = true } }

# document.output
puts document.parts
