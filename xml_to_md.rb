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

module SAXNodes
  def preface_open(name, attrs)
    @parts[:preface] = @output = []
  end

  def preface_close(name, attrs)
    @output = []
  end

  def line_open(name, attrs)
    @output << "\n\n" unless @output.last == "\n\n"
  end

  def italic(string)
    @output << "_#{string}_"
  end

  def bold(string)
    @output << "__#{string}__"
  end

  def change(string)
    @output << "___#{string}___"
  end
end

class MCMDoc < Nokogiri::XML::SAX::Document
  include SAXNodes

  attr_reader :output
  attr_reader :parts

  def initialize
    super
    @output = []
    @parts = {}
    @whole_node_cache = []
  end

  def start_element(name, attrs=[])
    method_name = "#{name}_open".downcase.to_sym
    if SAXNodes.method_defined?(method_name)
      send(method_name, name, attrs)
    end

    start_whole_node(name, attrs)
  end

  def end_element(name, attrs=[])
    method_name = "#{name}_close".downcase.to_sym
    if SAXNodes.method_defined?(method_name)
      send(method_name, name, attrs)
    end

    end_whole_node(name, attrs)
  end

  def characters(string)
    puts string if string.include? '&bull;'
    @output << clean_text(string) unless continue_whole_node(string)
  end
  #
  # def error string
  #   puts "ERROR #{string}"
  # end

  def output
    @parts.each do |key, value|
      File.open("manual/#{key}.md", 'w') { |file| file.write(value.join('')) }
    end
  end

  private

  def start_whole_node(name, attrs)
    method_name = name.downcase.to_sym
    if SAXNodes.method_defined?(method_name)
      @whole_node_cache << {key: method_name, value: []}
    end
  end

  def continue_whole_node(string)
    @whole_node_cache.last&.fetch(:value)&.push(string)
  end

  def end_whole_node(name, attrs)
    method_name = name.downcase.to_sym
    last = @whole_node_cache.last
    return if !last

    if last[:key] != method_name
      puts "ERROR"
      return
    end

    output = last[:value].join('')
    @whole_node_cache.pop
    send(method_name, output)
  end
end

document = MCMDoc.new
parser = Nokogiri::XML::SAX::Parser.new(document)
File.open('mcm_5_jun_2016.xml') { |f| parser.parse(f) { |ctx| ctx.recovery = true } }

document.output
