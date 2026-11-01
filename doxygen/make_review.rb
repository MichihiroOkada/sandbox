#!/usr/bin/env ruby
# make_review.rb

require 'asciidoctor'
require 'diff/lcs'
require 'cgi'
require 'nokogiri'

abort "usage: ruby make_review.rb file.adoc" if ARGV.size != 1

target_file = ARGV[0]

unless File.exist?(target_file)
  abort "file not found: #{target_file}"
end

#------------------------------------------------------------------------------
# HEAD版取得
#------------------------------------------------------------------------------

old_adoc = `git show HEAD:"#{target_file}" 2>nul`

if !$?.success? || old_adoc.empty?
  puts "warning: file not found in HEAD."
  old_adoc = ""
end

new_adoc = File.read(target_file)

#------------------------------------------------------------------------------
# AsciiDoc -> HTML
#------------------------------------------------------------------------------

def render_asciidoc(src)
  Asciidoctor.convert(
    src,
    safe: :safe,
    backend: 'html5',
    header_footer: false
  )
end

old_html = render_asciidoc(old_adoc)
new_html = render_asciidoc(new_adoc)

#------------------------------------------------------------------------------
# HTML -> 画面表示テキスト抽出
#------------------------------------------------------------------------------

def visible_lines(html)
  doc = Nokogiri::HTML.fragment(html)

  text = doc.text

  text
    .split(/\R/)
    .map(&:strip)
    .reject(&:empty?)
end

old_lines = visible_lines(old_html)
new_lines = visible_lines(new_html)

#------------------------------------------------------------------------------
# 単語差分
#------------------------------------------------------------------------------

def html_escape(str)
  CGI.escapeHTML(str.to_s)
end

def word_diff(old_text, new_text)

  old_words = old_text.split(/(\s+)/)
  new_words = new_text.split(/(\s+)/)

  changes = Diff::LCS.sdiff(old_words, new_words)

  out = ""

  changes.each do |c|

    case c.action
    when '='
      out << html_escape(c.new_element)

    when '-'
      out << %Q(<span class="deleted">#{html_escape(c.old_element)}</span>)

    when '+'
      out << %Q(<span class="added">#{html_escape(c.new_element)}</span>)

    when '!'
      out << %Q(<span class="deleted">#{html_escape(c.old_element)}</span>)
      out << %Q(<span class="added">#{html_escape(c.new_element)}</span>)
    end
  end

  out
end

#------------------------------------------------------------------------------
# 行単位比較
#------------------------------------------------------------------------------

result = []

Diff::LCS.sdiff(old_lines, new_lines).each do |change|

  case change.action

  when '='
    result << %Q(<div class="same">#{html_escape(change.new_element)}</div>)

  when '-'
    result << %Q(<div class="line-del">#{html_escape(change.old_element)}</div>)

  when '+'
    result << %Q(<div class="line-add">#{html_escape(change.new_element)}</div>)

  when '!'

    result << %Q(
<div class="line-del">
#{word_diff(change.old_element, "")}
</div>
)

    result << %Q(
<div class="line-add">
#{word_diff("", change.new_element)}
</div>
)
  end

end

#------------------------------------------------------------------------------
# HTML出力
#------------------------------------------------------------------------------

output_html = <<~HTML
<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">

<title>Review Diff</title>

<style>

body{
    font-family: Meiryo, "Yu Gothic", sans-serif;
    margin: 30px;
    line-height: 1.8;
    font-size: 15px;
}

h1{
    border-bottom: 2px solid #ccc;
}

.same{
    padding:4px 8px;
}

.line-add{
    background:#eefaff;
    border-left:5px solid #4db8ff;
    padding:4px 8px;
    margin:2px 0;
}

.line-del{
    background:#fff0f5;
    border-left:5px solid #ff69b4;
    padding:4px 8px;
    margin:2px 0;
}

.added{
    background:#cfefff;
    color:#004466;
}

.deleted{
    background:#ffd6e5;
    color:#990033;
    text-decoration:line-through;
}

.legend{
    margin-bottom:20px;
}

</style>
</head>

<body>

<h1>AsciiDoc Review Diff</h1>

<div class="legend">
<span class="added">追加</span>
　
<span class="deleted">削除</span>
</div>

#{result.join("\n")}

</body>
</html>
HTML

review_file =
  target_file
    .sub(/\.adoc$/i, ".review.html")

File.write(review_file, output_html)

puts "generated: #{review_file}"
