require 'cgi'
require 'shellwords'

class ConvertToPDF
  PDF_OPTIONS = {
    page_size: 'A4'
  }.freeze

  def initialize(params = {})
    if !params.key?(:from) || params[:from].nil?
      raise ArgumentError.new 'where is the codebase you want to convert to PDF?'
    elsif !valid_directory?(params[:from])
      raise LoadError.new "#{params[:from]} not found"
    elsif !params.key?(:to) || params[:to].nil?
      raise ArgumentError.new 'where should I save the generated pdf file?'
    else
      @from, @to, @except, @theme_name, @font_size, @enable_lineno, @margin_lr = params[:from], params[:to], params[:except].to_s, params[:theme], params[:font_size], params[:enable_lineno], params[:margin_lr]

      if File.exist?(@except) && invalid_blacklist?
        raise LoadError.new "#{@except} is not a valid blacklist YAML file"
      end

      save
    end
  end

  private

  def save
    pdf.to_file(@to)
  end

  def pdf
    html ||= ''

    if @font_size.nil?
      @font_size = 16
    end

    if @margin_lr.nil?
      @margin_lr = 0.3
    end

    if @enable_lineno.nil?
      @enable_lineno = true
    end

    style = "size: #{@font_size}; font-family: Helvetica, sans-serif; font-size: #{@font_size}px;"

    html += "<style> .table_style { font-size: #{@font_size}px; } </style>"
    if !@enable_lineno
      html += "<style> .gutter_style { display: none; } </style>"
    end

    read_files.each do |file|
      html += "<strong style='#{style}'>File: #{file.first}</strong></br></br>"
      html += prepare_line_breaks(syntax_highlight(file)).to_s
      html += add_space(30)
    end

    PDFKit.new(html, page_size: 'A4', margin_left: @margin_lr+'in', margin_right: @margin_lr+'in')
  end

  def syntax_highlight(file)
    file_type = File.extname(file.first)[1..-1]
    file_lexer = Rouge::Lexer.find(file_type)
    return CGI.escapeHTML(file.last) unless file_lexer

    if @theme_name == "github"
      theme = Rouge::Themes::Github.new
    elsif @theme_name == "bw"
      theme = Rouge::Themes::BlackWhiteTheme
    elsif @theme_name == "colorful"
      theme = Rouge::Themes::Colorful
    elsif @theme_name == "gruvbox_light"
      theme = Rouge::Themes::Gruvbox.mode(:light)
    elsif @theme_name == "gruvbox_dark"
      theme = Rouge::Themes::Gruvbox.mode(:dark)
    elsif @theme_name == "igor_pro"
      theme = Rouge::Themes::IgorPro
    elsif @theme_name == "magritte"
      theme = Rouge::Themes::Magritte
    elsif @theme_name == "molokai"
      theme = Rouge::Themes::Molokai
    elsif @theme_name == "monokai"
      theme = Rouge::Themes::Monokai
    elsif @theme_name == "monokai_sublime"
      theme = Rouge::Themes::MonokaiSublime
    elsif @theme_name == "pastie"
      theme = Rouge::Themes::Pastie
    elsif @theme_name == "thankful_eyes"
      theme = Rouge::Themes::ThankfulEyes
    elsif @theme_name == "tulip"
      theme = Rouge::Themes::Tulip
    elsif @theme_name == "base16_light"
      theme = Rouge::Themes::Base16.mode(:light)
    elsif @theme_name == "base16_dark"
      theme = Rouge::Themes::Base16.mode(:dark)
    else theme = Rouge::Themes::Github.new
    end

    formatter = Rouge::Formatters::HTMLInline.new(theme)
    formatter = Rouge::Formatters::HTMLTable.new(formatter, start_line: 1, table_class: 'table_style', gutter_class: 'gutter_style')
    code_data = file.last.encode('UTF-8', 'binary', invalid: :replace, undef: :replace, replace: '')
    formatter.format(file_lexer.lex(code_data))
  end

  def invalid_blacklist?
    return true if FileTest.directory?(@except)

    @blacklist = YAML.load_file(@except)

    !@blacklist.key?(:directories) || !@blacklist.key?(:files)
  end

  def in_directory_blacklist?(item_path)
    @blacklist[:directories].include?(item_path.gsub("#{@from}/", '')) if @blacklist
  end

  def in_file_blacklist?(item_path)
    if @blacklist
      @blacklist[:files].include?(item_path.split('/').last) || @blacklist[:files].include?(item_path.gsub("#{@from}/", ''))
    end
  end

  def valid_directory?(dir)
    File.exist?(dir) && FileTest.directory?(dir)
  end

  def valid_file?(file)
    File.exist?(file) && FileTest.file?(file)
  end

  def read_files(path = nil)
    @files ||= []
    path ||= @from

    Dir.foreach(path) do |item|
      item_path = "#{path}/#{item}"

      if valid_directory?(item_path) && !%w[. ..].include?(item) && !in_directory_blacklist?(item_path)
        read_files(item_path)
      elsif valid_file?(item_path) && !in_file_blacklist?(item_path)
        @files << [item_path, process_file(item_path)]
      end
    end

    @files
  end

  def process_file(file)
    puts "Reading file #{file}"

    content = ''
    File.open(file, 'r') do |f|
      if `file #{file.shellescape}` !~ /text/
        content << '[binary]'
      else
        f.each_line { |line_content| content << line_content }
      end
    end
    content
  end

  def prepare_line_breaks(content)
    content.gsub(/\n/, '<br>')
  end

  def add_space(height)
    "<div style='margin-bottom: #{height}px'>&nbsp;</div>"
  end
end