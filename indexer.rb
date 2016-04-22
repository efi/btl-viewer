# encoding: utf-8
Encoding.default_external = 'utf-8'
Encoding.default_internal = 'utf-8'
require 'rubygems'
require 'bundler'
Bundler.require

@@indexname = 'btlviewer'

class StructureAnalyzer < Nokogiri::XML::SAX::Document
  def initialize
    @path=[]
    @stat={}
  end
  def start_element name, attr=[]
    slot = [@stat,@path].flatten.inject{|x,y|x ?x[y]:y}
    @path<<name
    slot[name] ||= {}
    slot[name]["_count"] ||= 0
    slot[name]["_count"] += 1
    attr.each do |k,v|
      slot[name]["@#{k}"] ||= 0
      slot[name]["@#{k}"] += 1
    end
  end
  def end_element name, attr=[]
    @path.delete_at -1
  end

  def display x, lvl=0
    return unless x.respond_to? :keys
    (x.keys-["_count"]).sort.each do |k|
      childcount = x[k].respond_to?(:keys) ? x[k]['_count'] : x[k]
      count = x["_count"]||1
      puts "#{"  "*lvl}[#{k}] * #{childcount} (#{(1.0*childcount/count*100).round(2)}%)"
      display x[k], lvl+1
    end
  end
  def end_document
    display @stat
  end
end

class Indexer < Nokogiri::XML::SAX::Document
  def initialize
    @state = :idle
    @buffer = {path:[]}
  end
  def error e
    puts "E: #{e}"
  end
  def warning e
    puts "#W: {w}"
  end
  def value array, name
    array.select{|k,v|k==name.to_s}.map(&:last).first
  end
  def start_element name, attr=[]
    case name
    when "book-part"
      @buffer = {id:value(attr,:id), abstract:[], authors:[], aetas:[], century:[], chronology:[], genre:[], tll_code:[], lla:[], path:[], text:[], text_with_path:[]}
      @path = 0 ; @pathchanged = true
      @mode = :meta
    when "abstract"
      @state = :abstract
    when "string-name"
      @state = :authors
    when "kwd-group"
      @state = value(attr,"kwd-group-type").downcase.to_sym
    when "compound-kwd"
      if @state == :etoc && value(attr,"content-type")
        @path = value(attr,"content-type").split("_").last.to_i-1
        @buffer[:path]=@buffer[:path][0..@path]
        @pathchanged = true
      end
    when "compound-kwd-part"
      if @state == :etoc && value(attr,"content-type")
        @path = value(attr,"content-type").split("_").last.to_i-1 
        @pathchanged = true
      end
      @state = value(attr,"content-type").downcase.to_sym if value(attr,"content-type") && @state != :etoc && @mode == :meta
    when "body"
      @mode = :body
    when "p"
      @state = :text if @mode == :body
    when "named-content"
      @state = value(attr,"content-type")=="excl" ? :exclude : :text_foreign
    end
  end
  def characters s
    return if s.strip == ""
    text = @state == :text_foreign ? s.gsub(/~\S+/,"") : s
    state = @state == :text_foreign ? :text : @state
    if state==:text
      newpath = @buffer[:path][2..-1].flatten.map(&:strip).join(" – ")
      @buffer[:text_with_path] << (@oldpath==newpath ? text : "<span class=\"path\">#{newpath}</span>#{text}")
      @oldpath = newpath
    end
    if @state == :etoc
      @buffer[:path][@path] = [] if @pathchanged
      @buffer[:path][@path] << s
      @pathchanged = false
      return
    end
    @buffer[state] << text unless [:idle, :exclude].include? state
  end
  def end_element name
    oldstate = @state
    @state = :idle
    case name
    when "book-part"
      @buffer[:path] = @buffer[:path].map{|x|x.join("")}
      id          = "#{@buffer[:id].strip}"
      author      = "#{@buffer[:authors].join(', ')}".strip
      title       = "#{@buffer[:path][1]}".strip
      content     = "#{@buffer[:text].join('')}".gsub("<","&lt;").gsub(">","&gt;")
      content_raw = "#{@buffer[:text_with_path].join("\n")}"#.gsub("<","&lt;").gsub(">","&gt;").gsub("&lt;span class=\"path\";gt","<span class=\"path\">").gsub("&lt;/span&gt;","</span>")
      dating      = "#{@buffer[:century].first} | #{@buffer[:chronology].first}".strip
      @@index.index :index=>@@indexname, :type=>'work', :id=>id, :body=>{:author=>author, :author_raw=>author, :title=>title, :title_raw=>title, :content=>content, :content_raw=>content_raw, :dating=>dating}
      #@@index.search(:index=>@@indexname, :body=>{ :query=>{ :match=>{ content: 'hunc' }}})["hits"]["total"]
    when "abstract"
        when "string-name"
    when "kwd-group"
    when "compound-kwd-part"
      @state = oldstate if oldstate == :etoc
    when "p"
      @buffer[:text] << "\n"
    when "named-content"
      @state = :text
    else
      @state = oldstate
    end
  end
  def end_document
  end
end

@@index = Elasticsearch::Client.new log: false
@@index.indices.delete :index=>@@indexname if @@index.indices.exists :index=>@@indexname
@@index.indices.create :index=>@@indexname, :body=>{:settings=>{:number_of_shards=>1,:number_of_replicas=>1}, :mappings=>{"work"=>{:properties=>{
  "id"           => {:type=>"string", :index=>"analyzed",     :analyzer=>"keyword", :store=>true},
  "author"       => {:type=>"multi_field", :fields=> {
    "author"     => {:type=>"string", :index=>"analyzed",     :analyzer=>"simple",  :store=>true},
    "author_raw" => {:type=>"string", :index=>"not_analyzed",                       :store=>false, :include_in_all=>false}
  }},
  "title"        => {:type=>"multi_field", :fields=> {
    "title"      => {:type=>"string", :index=>"analyzed",     :analyzer=>"simple",  :store=>true},
    "title_raw"  => {:type=>"string", :index=>"not_analyzed",                       :store=>false, :include_in_all=>false}
  }},
  "content"      => {:type=>"multi_field", :fields=> {
    "content"    => {:type=>"string", :index=>"analyzed",     :anaylzer=>"simple",  :store=>true },#, :index_options=>"offsets"},
    "content_raw"=> {:type=>"string", :index=>"not_analyzed",                       :store=>true, :include_in_all=>false },
  }},
  "dating"       => {:type=>"string", :index=>"analyzed",         :anaylzer=>"simple",  :store=>true}
}}}}
Nokogiri::XML::SAX::Parser.new(Indexer.new).parse_file("xml/BTL_OUT_2011-01_modified_20140212.xml")

exit