#!/usr/bin/env ruby
# frozen_string_literal: true

# Build a full HTML review copy of an AsciiDoc file. PlantUML source blocks
# remain untouched on disk; in the temporary conversion they are rendered as
# SVG diagrams and changed diagrams are listed at the top of the HTML.

require 'json'

# json 3.x removed the legacy create_additions keyword. Some diagram-related
# gems still pass create_additions: false to JSON.load/parse. Bridge that old
# call to json 3.x while preserving the safe default; only an explicit true
# uses JSON.unsafe_load, matching the caller's requested behavior.
module JsonCreateAdditionsCompatibility
  def load(source, proc = nil, *legacy_args, **options, &block)
    create_additions, legacy_args, options = extract_create_additions(legacy_args, options)
    return JSON.unsafe_load(source, proc, *legacy_args, **options) if create_additions

    super(source, proc, *legacy_args, **options, &block)
  end

  def parse(source, *legacy_args, **options, &block)
    create_additions, legacy_args, options = extract_create_additions(legacy_args, options)
    return JSON.unsafe_load(source, *legacy_args, **options) if create_additions

    super(source, *legacy_args, **options, &block)
  end

  def parse!(source, *legacy_args, **options, &block)
    create_additions, legacy_args, options = extract_create_additions(legacy_args, options)
    return JSON.unsafe_load(source, *legacy_args, max_nesting: false, allow_nan: true, **options) if create_additions

    super(source, *legacy_args, **options, &block)
  end

  private

  def extract_create_additions(legacy_args, options)
    options = options.dup
    create_additions = options.delete(:create_additions)
    legacy_args = legacy_args.dup
    if legacy_args.last.is_a?(Hash) && legacy_args.last.key?(:create_additions)
      legacy_options = legacy_args.pop.dup
      create_additions = legacy_options.delete(:create_additions)
      options = legacy_options.merge(options)
    end
    [create_additions, legacy_args, options]
  end
end

JSON.singleton_class.prepend(JsonCreateAdditionsCompatibility)

require 'asciidoctor'
require 'open3'
require 'optparse'
require 'pathname'
require 'cgi'
require 'diff/lcs'
require 'nokogiri'

begin
  require 'asciidoctor-diagram'
rescue LoadError => e
  abort <<~MSG
    Could not load asciidoctor-diagram (#{e.message}).
    Install the Asciidoctor Diagram gem, then rerun this script:
      gem install asciidoctor-diagram
    PlantUML rendering also requires Java.
  MSG
end

DiagramBlock = Struct.new(
  :path, :source, :start_line, :close_line, :number, :status,
  keyword_init: true
)

options = { base: 'HEAD', base_file: nil }
parser = OptionParser.new do |opts|
  opts.banner = 'Usage: ruby make_diagram_review.rb [options] input.adoc [output.html]'
  opts.on('--base REF', 'Git ref to compare with (default: HEAD)') { |v| options[:base] = v }
  opts.on('--base-file PATH', 'Compare with a previous AsciiDoc file (relative to input file directory)') { |v| options[:base_file] = v }
  opts.on('-h', '--help', 'Show this help') do
    puts opts
    exit
  end
end

begin
  parser.parse!
rescue OptionParser::ParseError => e
  abort "#{e.message}\n#{parser}"
end

input_arg = ARGV.shift
abort parser.to_s unless input_arg

input = Pathname(input_arg).expand_path
abort "Input file not found: #{input}" unless input.file?

output = if ARGV[0]
  Pathname(ARGV[0]).expand_path
else
  Pathname(input.dirname.to_s).join("#{input.basename(input.extname)}.review.html")
end

# Find the repository root and the input path relative to it, then read the
# base version without invoking a shell (so paths with spaces are safe).
repo_root = nil
old_source = nil
if options[:base_file]
  base_file = Pathname(options[:base_file])
  base_file = input.dirname.join(base_file) unless base_file.absolute?
  abort "Base file not found: #{base_file}" unless base_file.file?
  old_source = File.read(base_file, encoding: 'UTF-8')
  puts "Comparing with file: #{base_file}"
else
  repo_out, repo_status = Open3.capture2('git', 'rev-parse', '--show-toplevel', chdir: input.dirname.to_s)
  if repo_status.success?
    repo_root = Pathname(repo_out.strip)
    begin
      relative_input = input.relative_path_from(repo_root).to_s.tr('\\', '/')
      base_out, base_status = Open3.capture2('git', 'show', "#{options[:base]}:#{relative_input}", chdir: repo_root.to_s)
      old_source = base_out.force_encoding(Encoding::UTF_8) if base_status.success?
    rescue ArgumentError
      # Input outside the repository; handled by the missing-base warning below.
    end
  end
  unless old_source
    warn 'Warning: no base version was found for this path; every current block will appear as added. Use --base-file to compare against another AsciiDoc file.'
    old_source = ''
  end
end

new_source = File.read(input, encoding: 'UTF-8')

# PlantUML blocks are identified by [plantuml] or [source,plantuml]. Their
# headings and occurrence number within a heading provide a stable-enough key
# for matching diagrams between revisions.
def parse_plantuml_blocks(source)
  lines = source.lines
  headings = []
  per_heading_count = Hash.new(0)
  blocks = []
  i = 0

  while i < lines.length
    line = lines[i].to_s.chomp

    if (heading = line.match(/\A(={1,6})\s+(.+?)\s*\z/))
      depth = heading[1].length
      title = heading[2].strip
      if depth == 1
        headings = []
      else
        headings = headings.take(depth - 2)
        headings[depth - 2] = title
        headings = headings.take(depth - 1)
      end
      i += 1
      next
    end

    attrs = line.match(/\A\s*\[([^\]]+)\]\s*\z/)
    if attrs && i + 1 < lines.length
      delimiter = lines[i + 1].to_s.chomp.strip
      if delimiter.match?(/\A(?:-{4,}|\.{4,})\z/)
        close_line = (i + 2...lines.length).find do |line_index|
          lines[line_index].to_s.chomp.strip == delimiter
        end

        if close_line
          content = lines[(i + 2)...close_line].join
          if plantuml_block?(attrs[1], content)
            section_path = headings.compact.join(' / ')
            section_path = '(document)' if section_path.empty?
            per_heading_count[section_path] += 1
            blocks << DiagramBlock.new(
              path: section_path,
              source: content,
              start_line: i,
              close_line: close_line,
              number: per_heading_count[section_path]
            )
          end
          i = close_line + 1
          next
        end
      end
    end

    i += 1
  end

  blocks
end

def plantuml_block?(text, source)
  tokens = text.split(',').map(&:strip).map(&:downcase)
  return true if tokens[0] == 'plantuml' || (tokens[0] == 'source' && tokens[1] == 'plantuml')

  source.match?(/^\s*@startuml\b/i) && source.match?(/^\s*@enduml\b/i)
end

# Align diagram blocks within each section. Exact matches are kept; unmatched
# old/new runs are paired as modifications, with any remainder treated as
# added or deleted diagrams.
def classify_diagrams(old_blocks, new_blocks)
  status_by_object = {}
  deleted = []
  matched_pairs = {}
  paths = (old_blocks.map(&:path) + new_blocks.map(&:path)).uniq

  paths.each do |path|
    old_group = old_blocks.select { |block| block.path == path }
    new_group = new_blocks.select { |block| block.path == path }
    n = old_group.length
    m = new_group.length
    lcs = Array.new(n + 1) { Array.new(m + 1, 0) }

    (n - 1).downto(0) do |i|
      (m - 1).downto(0) do |j|
        lcs[i][j] = if old_group[i].source == new_group[j].source
          lcs[i + 1][j + 1] + 1
        else
          [lcs[i + 1][j], lcs[i][j + 1]].max
        end
      end
    end

    ops = []
    i = 0
    j = 0
    while i < n && j < m
      if old_group[i].source == new_group[j].source
        ops << [:same, old_group[i], new_group[j]]
        i += 1
        j += 1
      elsif lcs[i + 1][j] >= lcs[i][j + 1]
        ops << [:delete, old_group[i], nil]
        i += 1
      else
        ops << [:add, nil, new_group[j]]
        j += 1
      end
    end
    while i < n
      ops << [:delete, old_group[i], nil]
      i += 1
    end
    while j < m
      ops << [:add, nil, new_group[j]]
      j += 1
    end

    pending_old = []
    pending_new = []
    flush = lambda do
      paired = [pending_old.length, pending_new.length].min
      paired.times do |k|
        status_by_object[pending_new[k].object_id] = :changed
        matched_pairs[pending_old[k].object_id] = pending_new[k]
      end
      pending_new.drop(paired).each { |block| status_by_object[block.object_id] = :added }
      deleted.concat(pending_old.drop(paired))
      pending_old.clear
      pending_new.clear
    end

    ops.each do |action, old_block, new_block|
      case action
      when :same
        flush.call
        status_by_object[new_block.object_id] = :unchanged
        matched_pairs[old_block.object_id] = new_block
      when :delete
        pending_old << old_block
      when :add
        pending_new << new_block
      end
    end
    flush.call
  end

  [status_by_object, deleted, matched_pairs]
end

old_blocks = parse_plantuml_blocks(old_source)
new_blocks = parse_plantuml_blocks(new_source)
statuses, deleted_blocks, matched_diagram_pairs = classify_diagrams(old_blocks, new_blocks)

# Rewrite only the in-memory review copy: diagram source blocks become SVG
# PlantUML blocks. The original .adoc is never modified.
def prepare_review_source(source, blocks, statuses)
  lines = source.lines
  by_start = blocks.to_h { |block| [block.start_line, block] }
  out = []
  i = 0
  diagram_number = 0

  while i < lines.length
    block = by_start[i]
    unless block
      out << lines[i]
      i += 1
      next
    end

    diagram_number += 1
    status = statuses.fetch(block.object_id, :added)
    diagram_id = format('review-diagram-%04d', diagram_number)
    role = case status
    when :changed then ',role=diagram-changed'
    when :added then ',role=diagram-added'
    else ''
    end

    out << "[plantuml,#{diagram_id},svg,id=#{diagram_id}#{role}]\n"
    out.concat(lines[(block.start_line + 1)..block.close_line])
    i = block.close_line + 1
  end

  out.join
end

review_source = prepare_review_source(new_source, new_blocks, statuses)
old_statuses = old_blocks.to_h { |block| [block.object_id, :unchanged] }
old_review_source = prepare_review_source(old_source, old_blocks, old_statuses)

# Convert both complete documents with the same options. The current version
# is shown below the diff panel; the base version is used to compare rendered
# prose blocks. data-uri keeps rendered diagrams inside the HTML.
def render_asciidoc(source, input, output)
  Asciidoctor.convert(
    source,
    backend: 'html5',
    header_footer: false,
    safe: :safe,
    base_dir: input.dirname.to_s,
    attributes: {
      'docfile' => input.to_s,
      'docdir' => input.dirname.to_s,
      'docname' => input.basename(input.extname).to_s,
      'data-uri' => '',
      'outdir' => output.dirname.to_s,
      'imagesoutdir' => output.dirname.to_s
    }
  )
end

output.dirname.mkpath
old_html = render_asciidoc(old_review_source, input, output)
html_fragment = render_asciidoc(review_source, input, output)

def rendered_text_nodes(fragment)
  block_names = %w[h1 h2 h3 h4 h5 h6 p pre li th td dt dd blockquote]
  selector = block_names.join(',')

  fragment.css(selector).reject do |node|
    node.ancestors.any? { |ancestor| block_names.include?(ancestor.name) }
  end.reject { |node| node.text.gsub(/[\t\r\n\u00a0 ]+/, ' ').strip.empty? }
end

def normalized_text(node)
  text = node.text.gsub(/[\t\r\n\u00a0 ]+/, ' ').strip
  # Asciidoctor adds section numbers in the rendered HTML. Ignore those
  # generated prefixes when aligning headings so a renumbered document does
  # not turn every following section into a deletion/addition run.
  node.name.match?(/\Ah[1-6]\z/) ? text.sub(/\A\d+(?:\.\d+)*\.?\s+/, '') : text
end

# Put textual changes beside their corresponding rendered blocks in the full
# current document. Deletions are inserted before the next surviving block
# (or after the previous block at end of document).
def embed_prose_diff(old_html, current_fragment)
  old_dom = Nokogiri::HTML.fragment(old_html)
  old_nodes = rendered_text_nodes(old_dom)
  current_dom = Nokogiri::HTML.fragment(current_fragment)
  new_nodes = rendered_text_nodes(current_dom)
  old_blocks = old_nodes.map { |node| normalized_text(node) }
  new_blocks = new_nodes.map { |node| normalized_text(node) }
  changes = Diff::LCS.sdiff(old_blocks, new_blocks)
  insertions = []
  modified = []
  additions = []
  new_index = 0

  changes.each do |change|
    case change.action
    when '='
      new_index += 1
    when '-'
      # Anchor deletions before the next non-deleted new block. If no such
      # block remains, place them after the preceding current block.
      next_new_index = new_index
      target = new_nodes[next_new_index] || new_nodes[[new_index - 1, 0].max]
      if target
        insertions << [target, change.old_element, new_nodes[next_new_index].nil?]
      end
    when '+'
      additions << new_nodes[new_index] if new_nodes[new_index]
      new_index += 1
    when '!'
      if (node = new_nodes[new_index])
        insertions << [node, change.old_element, false]
        modified << node
      end
      new_index += 1
    end
  end

  insertions.each do |target, text, after|
    escaped_text = CGI.escapeHTML(text)
    markup = %(<div class="embedded-change deleted">#{escaped_text}</div>)
    after ? target.add_next_sibling(markup) : target.add_previous_sibling(markup)
  end
  (additions + modified).uniq.each do |node|
    node.add_class('embedded-added')
  end

  [changes.count { |change| change.action != '=' }, current_dom.to_html]
end

text_change_count, html_fragment = embed_prose_diff(old_html, html_fragment)

def diagram_image_node(fragment, global_index)
  id = format('review-diagram-%04d', global_index + 1)
  node = fragment.at_css("##{id}")
  return unless node

  node.name == 'div' && node['class'].to_s.split.include?('imageblock') ? node :
    node.ancestors.find { |ancestor| ancestor.name == 'div' && ancestor['class'].to_s.split.include?('imageblock') }
end

# Reinsert removed diagrams at their old position relative to surviving
# diagrams in the same section. The old rendered image is wrapped in the same
# pink deletion treatment used for deleted prose.
def embed_deleted_diagrams(old_html, current_html, old_blocks, new_blocks, deleted_blocks, matched_pairs)
  old_dom = Nokogiri::HTML.fragment(old_html)
  current_dom = Nokogiri::HTML.fragment(current_html)

  deleted_blocks.each do |deleted_block|
    old_index = old_blocks.index(deleted_block)
    old_image = diagram_image_node(old_dom, old_index) if old_index
    wrapper = Nokogiri::HTML.fragment('<div class="embedded-change deleted deleted-diagram"></div>').at_css('div')

    if old_image
      image_copy = old_image.dup(1)
      image_copy.css('[id]').each { |node| node.remove_attribute('id') }
      image_copy.remove_attribute('id')
      image_copy.add_class('deleted-diagram-image')
      wrapper.add_child(image_copy)
    else
      # Keep a useful indication if the old diagram could not be found in the
      # rendered base document.
      source = Nokogiri::XML::Text.new(deleted_block.source, current_dom.document)
      code = Nokogiri::XML::Node.new('pre', current_dom.document)
      code.add_class('deleted-diagram-source')
      code.add_child(source)
      wrapper.add_child(code)
    end

    old_position = old_blocks.index(deleted_block)
    following = old_blocks[(old_position + 1)..].to_a.find do |block|
      block.path == deleted_block.path && matched_pairs.key?(block.object_id)
    end
    preceding = old_blocks[0...old_position].reverse.find do |block|
      block.path == deleted_block.path && matched_pairs.key?(block.object_id)
    end

    if following
      target_block = matched_pairs[following.object_id]
      target = diagram_image_node(current_dom, new_blocks.index(target_block))
      target ? target.add_previous_sibling(wrapper) : current_dom.add_child(wrapper)
    elsif preceding
      target_block = matched_pairs[preceding.object_id]
      target = diagram_image_node(current_dom, new_blocks.index(target_block))
      target ? target.add_next_sibling(wrapper) : current_dom.add_child(wrapper)
    else
      # If every diagram in the section was removed, place it under the
      # section heading in the current document.
      title = deleted_block.path.split(' / ').last
      heading = current_dom.css('h1,h2,h3,h4,h5,h6').find do |node|
        heading_text = normalized_text(node).sub(/\A\d+(?:\.\d+)*\.?\s*/, '')
        heading_text == title
      end
      heading ? heading.add_next_sibling(wrapper) : current_dom.add_child(wrapper)
    end
  end

  current_dom.to_html
end

html_fragment = embed_deleted_diagrams(
  old_html, html_fragment, old_blocks, new_blocks, deleted_blocks, matched_diagram_pairs
)

# Convert the complete current document so its headings, numbering, tables,
# links, and prose keep their real context. data-uri makes the HTML portable.

summary_items = []
new_blocks.each_with_index do |block, index|
  status = statuses.fetch(block.object_id, :added)
  next unless [:changed, :added].include?(status)

  summary_items << %(<li class="diagram-added"><a href="##{format('review-diagram-%04d', index + 1)}">#{CGI.escapeHTML(block.path)}</a></li>)
end
deleted_blocks.each do |block|
  summary_items << %(<li class="diagram-removed">#{CGI.escapeHTML(block.path)}</li>)
end

summary = if summary_items.empty?
  '<p class="no-diagram-changes">PlantUML図に変更はありません。</p>'
else
  "<ul>#{summary_items.join}</ul>"
end

output_html = <<~HTML
  <!doctype html>
  <html lang="ja">
  <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>AsciiDoc レビュー</title>
    <style>
      body { margin: 0; color: #1f2328; background: #fff; font: 16px/1.6 -apple-system, BlinkMacSystemFont, "Segoe UI", Meiryo, sans-serif; }
      .markdown-body { box-sizing: border-box; max-width: 1012px; margin: 0 auto; padding: 32px; }
      .review-summary { margin: 24px auto; max-width: 948px; padding: 16px 20px; border: 1px solid #d0d7de; border-radius: 6px; background: #f6f8fa; }
      .review-summary h2 { margin: 0 0 8px; font-size: 1.1em; }
      .review-summary ul { margin: 0; padding-left: 1.5em; }
      .diagram-changed { color: #0550ae; }
      .diagram-added { color: #0969da; }
      .diagram-removed { color: #cf222e; }
      .no-diagram-changes { margin: 0; color: #656d76; }
      .embedded-change { margin: 8px 0; padding: 7px 10px; border-left: 4px solid transparent; white-space: pre-wrap; overflow-wrap: anywhere; }
      .embedded-change.deleted { background: #fff0f5; border-left-color: #ff69b4; }
      .deleted-diagram { display: block; }
      .deleted-diagram-image { margin-top: 8px; }
      .deleted-diagram-image img { max-width: 100%; }
      .embedded-added { box-sizing: border-box; margin: 8px 0; padding: 7px 10px; border-left: 4px solid #4db8ff; background: #eefaff; }
      .imageblock.diagram-changed, .imageblock.diagram-added { border-left: 4px solid #54aeff; padding-left: 12px; }
      h1, h2 { border-bottom: 1px solid #d8dee4; padding-bottom: .3em; }
      table { border-collapse: collapse; display: block; max-width: 100%; overflow: auto; }
      th, td { border: 1px solid #d0d7de; padding: 6px 13px; }
      th { font-weight: 600; background: #f6f8fa; }
      pre { overflow: auto; padding: 16px; background: #f6f8fa; border-radius: 6px; }
      code { font-family: ui-monospace, SFMono-Regular, Consolas, monospace; }
      img { max-width: 100%; height: auto; }
      .admonitionblock { margin: 16px 0; }
    </style>
  </head>
  <body>
    <aside class="review-summary">
      <h2>PlantUML図の変更</h2>
      #{summary}
    </aside>
    <main class="markdown-body">
      #{html_fragment}
    </main>
  </body>
  </html>
HTML

File.write(output, output_html, encoding: 'UTF-8')
puts "Generated: #{output}"
puts "PlantUML blocks: #{new_blocks.length}; changed/added: #{new_blocks.count { |b| [:changed, :added].include?(statuses.fetch(b.object_id, :added)) }}; deleted: #{deleted_blocks.length}"
puts "Rendered text changes: #{text_change_count}"
