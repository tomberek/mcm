require 'oga'
require 'byebug'
require 'fileutils'
require 'active_support/inflector'

TEXT_CLEANERS = [
  [/&(emsp|ensp|thinsp);/, ' '],
  [/&(bull|mdash|ndash);/, '-'],
  [/&(ldquo|rdquo);/, "\""],
  [/&(lsquo|rsquo);/, "\'"],
  ['&hellip;', "..."],
  ['<?Pub Caret>', '']
]

ENTITY_REPLACEMENTS = [
  ['&sect;', "--SECT--"],
  ['&puncsp;', "--PUNCSP--"]
]

def clean_text(content)
  (TEXT_CLEANERS + ENTITY_REPLACEMENTS).each do |mapping|
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

# this is a hack due to some weird unicode bug
# it goes back through, finds our placeholders,
# and puts back the correct entities
def replace_entities(content)
  ENTITY_REPLACEMENTS.each do |mapping|
    content.gsub! mapping[1], mapping[0]
  end

  content
end

module SAXNodes
  def part_open(name, attrs)
    return if name.include? '.'
    part_label = attrs['label'].downcase.to_sym
    @output = []
  end

  def part_close(name, attrs)
    return if name.include? '.'
    @output = []
  end

  def preface_open(name, attrs)
    part_open 'part', {'label' => 'preface'}
  end

  def preface_close(name, attrs)
    part_close 'part', attrs
  end

  def line_open(name, attrs)
    @output << "\n\n" unless @output.last == '\n\n'
  end

  def para_open(name, attrs)
    @header_level += 1
    if rule_num = attrs['rulenum']
      @header_label = "Rule #{rule_num}."
    else
      @header_label = attrs['label']
    end
  end

  def para_close(name, attrs)
    @header_level -= 1
    @header_label = nil
  end

  alias_method :subpara_open, :para_open
  alias_method :subpara_close, :para_close

  def title(string)
    @header_level.times { @output << '#' }
    @output << " #{@header_label}" if @header_label
    @output << " #{string}\n\n"
    @header_label = nil

    unless @parts.has_value? @output
      @parts[string] = @output
    end
  end

  def paratext_open(name, attrs)
    return if !@header_label
    @output << "#{@header_label} "
    @header_label = nil
  end

  def chapter_open(name, attrs)
    @header_label = "CHAPTER #{attrs['label']}"
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
    @header_level = 1
    @header_label = nil
  end

  QUALIFIER_REGEX = /(\w+\.)?(\D+)/

  def on_element(namespace, name, attrs = {})
    unqualified_name = name.match(QUALIFIER_REGEX)[2] # removes `rule.` prefix or a # suffix
    method_name = "#{unqualified_name}_open".downcase.to_sym
    if SAXNodes.method_defined?(method_name)
      send(method_name, name, attrs)
    end

    start_whole_node(name, attrs)
  end

  def after_element(namespace, name, attrs = {})
    unqualified_name = name.match(QUALIFIER_REGEX)[2]
    method_name = "#{unqualified_name}_close".downcase.to_sym
    if SAXNodes.method_defined?(method_name)
      send(method_name, name, attrs)
    end

    end_whole_node(name, attrs)
  end

  def on_text(string)
    # clean_whitespace(string)
    @output << string
  end

  def output
    index = 0
    @parts.each do |key, value|
      File.open("#{index}-#{key.match(/[a-zA-Z ]+/)[0].parameterize}.md", 'w') { |file| file.write(replace_entities(clean_newlines(value.join('')))) }
      # File.open("manual/#{key}.md", 'w') { |file| file.write((value.join(''))) }
      index += 1
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
xml = File.read('legacy/mcm_5_jun_2016.xml').force_encoding 'BINARY'
xml = clean_text xml

Oga.sax_parse_html handler, xml

FileUtils.rm Dir.glob('[^README]*.md')
handler.output
