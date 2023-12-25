require 'open3'
require 'uri'
require 'nokogiri'

def convert_to_html(input)
  html, status = Open3.capture2("textutil -format rtf -convert html -stdin -stdout", stdin_data: input)
  if !status.success?
    raise "Failed to convert to html"
  end
  html
end

def html_to_rtf(html)
  rtf, status = Open3.capture2("textutil -format html -convert rtf -stdin -stdout", stdin_data: html)
  if !status.success?
    raise "Failed to convert to rtf"
  end
  rtf
end

def get_clipboard
  clip, status = Open3.capture2("pbpaste")
  if !status.success?
    raise "Failed to get clipboard"
  end
  clip
end

def valid_url?(url)
  URI.parse(url).kind_of?(URI::HTTP)
rescue
  false
end

def is_linkable?(doc)
  return false if doc.xpath('//body').children.count do |node|
    # Ignore Nokogiri::XML::Text nodes
    !node.is_a?(Nokogiri::XML::Text)
  end != 1

  return false if doc.xpath('//a').count != 0

  true
end

# NOTE: This is assuming the specific HTML format that comes from Apple Notes,
# where the selected text is wrapped in a p or ul tag. Reinserting that tag in
# the output creates an extra line break, so we instead replace the container
# with its inner content.
def add_link(doc, url)
  body = doc.xpath('//body')
  container = body.children.find do |node|
    !node.is_a?(Nokogiri::XML::Text)
  end
  container.replace("<a href=\"#{url}\">#{container.inner_html}</a>")
end

# ==================== RUN SCRIPT ====================

DEBUG = false

script_dir = File.expand_path(File.dirname(__FILE__))
log = File.join(script_dir, 'linker.log')
input = ARGF.read
is_rtf = input.start_with?('{\rtf')

File.open(log, 'a') do |f|
  f.puts "----"
  if DEBUG
    f.puts "input:"
    f.puts input
    f.puts "rtf?"
    f.puts is_rtf.inspect
    f.puts "empty?"
    f.puts input.empty?.inspect
  end

  if !is_rtf || input.empty?
    f.puts "Empty or not rtf, exiting"
    f.puts
    exit
  end

  link = get_clipboard
  if DEBUG
    f.puts "link:"
    f.puts link
  end
  if !valid_url?(link)
    f.puts "Invalid URL, exiting"
    exit
  end

  html = convert_to_html(input)
  html.force_encoding('UTF-8')
  html_doc = Nokogiri.parse(html)
  if DEBUG
    f.puts "html:"
    f.puts html_doc.to_s
  end

  linkable = is_linkable?(html_doc)
  if !linkable
    f.puts "Not linkable, exiting"
    exit
  end

  add_link(html_doc, link)

  rtf_result = html_to_rtf(html_doc.to_s)
  if DEBUG
    f.puts "linked:"
    f.puts rtf_result
  end
  print rtf_result

  f.puts
end
