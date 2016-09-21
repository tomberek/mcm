require 'oga'
require 'byebug'

TEXT_CLEANERS = [
  [/&(emsp|ensp|thinsp);/, ' '],
  [/&(bull|mdash|ndash);/, '-'],
  [/&(ldquo|rdquo);/, "\""],
  [/&(lsquo|rsquo);/, "\'"],
  ['&sect;', "--SECT--"],
  ['&lsqb;', "--LSQP--"], ['&rsqb;', "--RSQP--"],
  ['&puncsp;', "--PUNCSP--"],
  ['&hellip;', "..."],
  ['<?Pub Caret>', '']
]

def clean_text(content)
  TEXT_CLEANERS.each do |mapping|
    content.gsub! mapping[0], mapping[1]
  end

  content
end

def clean_newlines(content)
  content.gsub! /\r|\n{1}/, "\n"
  content.gsub! /\r|\n{2,}/, "\n\n"
end

def clean_whitespace(content)
  content.gsub! /\r|\n/, ''
  content.gsub! /\s+/, ' '
end

module SAXNodes
  def preface_open(name, attrs)
    @parts[:preface] = @output = []
  end

  def preface_close(name, attrs)
    @output = []
  end

  def line_open(name, attrs)
    @output << "\n\n" unless @output.last == '\n\n'
  end

  def italic(string)
    @output << "_#{string}_"
  end

  def bold(string)
    @output << "**#{string}**"
  end

  def change(string)
    @output << "___#{string}___"
  end

  def sigblock(string)
    @output << "\n\n```sigline\n#{string}```"
  end

  def sigline(string)
    @output << "#{string}\n"
  end
end

class MCMDoc
  include SAXNodes

  attr_reader :output
  attr_reader :parts

  def initialize
    @output = []
    @parts = {}
    @whole_node_cache = []
  end

  def on_element(namespace, name, attrs = {})
    method_name = "#{name}_open".downcase.to_sym
    if SAXNodes.method_defined?(method_name)
      send(method_name, name, attrs)
    end

    start_whole_node(name, attrs)
  end

  def after_element(namespace, name, attrs = {})
    method_name = "#{name}_close".downcase.to_sym
    if SAXNodes.method_defined?(method_name)
      send(method_name, name, attrs)
    end

    end_whole_node(name, attrs)
  end

  def on_text(string)
    clean_whitespace(string)
    @output << string
  end

  def output
    @parts.each do |key, value|
      File.open("manual/#{key}.md", 'w') { |file| file.write(clean_newlines(value.join(''))) }
    end
  end

  private

  def start_whole_node(name, attrs)
    method_name = name.downcase.to_sym
    if SAXNodes.method_defined?(method_name)
      @whole_node_cache << {key: method_name, previous: @output, value: []}
      @output = @whole_node_cache.last[:value]
    end
  end

  def end_whole_node(name, attrs)
    method_name = name.downcase.to_sym
    last = @whole_node_cache.last
    return if !last

    if last[:key] != method_name
      puts "ERROR #{method_name}" unless method_name == :line
      return
    end

    string = last[:value].join('')
    @output = last[:previous]

    send(method_name, string)

    @whole_node_cache.pop
  end
end

handler = MCMDoc.new
xml = File.read('mcm_5_jun_2016.xml').dup.force_encoding('BINARY')
xml = clean_text(xml)

Oga.sax_parse_html(handler, xml)

handler.output
