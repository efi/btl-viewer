# encoding: utf-8
Encoding.default_external = 'utf-8'
Encoding.default_internal = 'utf-8'
require 'rubygems'
require 'bundler'
Bundler.require

set :bind, '127.0.0.1'
set :port, 80
use Rack::Reloader
use Rack::Auth::Basic, "Passwortgesicherter Bereich" do |username, password|
  username == 'i_am_aware_that_i_have_to_change_the' and password == 'password'
end
logfile = File.new("#{settings.root}/#{settings.environment}.log", 'a+')
logfile.sync = true
use Rack::CommonLogger, logfile
@@index = Elasticsearch::Client.new log: false
@@btl="btlviewer"

get "/" do haml <<___
%form{action:"javascript:search();"}
  .input-group
    %span.input-group-addon
      %span.glyphicon.glyphicon-th-list.top-indicator
    %input.form-control.query{name:"q", placeholder:"Bitte Suchbegrif eingeben", type:"text"}
    %span.input-group-btn
      %button.btn.btn-default{type:"submit"}
        %span.glyphicon.glyphicon-search
        Suchen
%h3.resulttitle
%ol.list-group.results
.jumbotron
  %em
    Suchbeispiele:
  %ul
    %li
      Volltextsuche:
      %a{href:"javascript:void(0);", onclick:"example($(this).text())"}thomas
    %li
      Trunkierte Suche:
      %a{href:"javascript:void(0);", onclick:"example($(this).text())"}*pileps*
    %li
      Filterung nach Autor:
      %a{href:"javascript:void(0);", onclick:"example($(this).text())"}morb* AND author:Polemius
    %li
      Filterung nach Titel:
      %a{href:"javascript:void(0);", onclick:"example($(this).text())"}clade* AND title:retract*
    %li
      Phrase:
      %a{href:"javascript:void(0);", onclick:"example($(this).text())"}"quid est epistola"
    %li
      Negierung:
      %a{href:"javascript:void(0);", onclick:"example($(this).text())"}clavicula AND !clavis
    %li
      Maximaler Abstand:
      %a{href:"javascript:void(0);", onclick:"example($(this).text())"}"thales milesius"~2
:javascript
  var moreAllowed=false;
  var page=1;
  function openDoc(id){
    $.ajax("/document/"+id+".json", {success:function(d){
      $.colorbox({width:"100%", height:"100%", fixed:true, title:id, html:'<div class="jumbotron"><h4><span class="glyphicon glyphicon-user"></span>&nbsp;<strong>'+d.author+'</strong><br /><span class="glyphicon glyphicon-book"></span>&nbsp;<em>'+d.title+'</em><br /><span class="glyphicon glyphicon-time"></span>&nbsp;'+d.dating+(d.similar?('</h4><br /><span class="glyphicon glyphicon-list-alt"></span> Die 10 ähnlichsten Dokumente (Beta):<br /><ul style="display:inline-block; max-width:600px; text-align:left;">'+$.makeArray($(d.similar).map(function(i,d){return '<li><a href="/document/'+d.id+'.json" onclick="openDoc('+"'"+d.id+"'"+');return false;">'+d.label+'</a> <small>('+((score=Math.floor(d.score*10000)/100.0)>50?'<b>'+score+'</b>':score)+'%)</small></li>'})).join(" ")+'</ul>'):'')+'</div><div class="text well">'+d.content.replace(new RegExp("\\n+","gm"),"\\n")+'</div>'});
    }});
  }
  function example(query){ $(".query").val(query); search(query); }
  function search(){
    $('.top-indicator').removeClass('glyphicon-th-list').addClass('glyphicon-refresh');
    $('.tt-dropdown-menu').fadeOut(100);
    $('.results').html('');
    page = 1;
    getMore();
  }
  var getMore = function(){
    more_allowed=false;
    var query = $('input[name=q]').val();
    $.ajax('/results?q='+encodeURIComponent(query)+"&page="+page++, { success:function(d){
      $('#indicator').remove();
      $('.top-indicator').addClass('glyphicon-th-list').removeClass('glyphicon-refresh');
      $('.resulttitle').text(""+d.hits+" Dokument"+(d.hits==1?'':'e')+" für Suchanfrage").append(" <em class=\\"querystring\\">"+query+"<em>");
      $(d.results).each(function(i,o){
        $('.results').append('<li class="list-group-item result"><span class="badge">'+o[0]+'</span><h3><span class="glyphicon glyphicon-user"></span>&nbsp;<strong>'+o[1]+'</strong><br /><a href="/document/'+o[0]+'.json" onclick="openDoc('+"'"+o[0]+"'"+');return false;"><span class="glyphicon glyphicon-book"></span>&nbsp;<em>'+o[2]+'</em></a></h3>'+$(o[3]).map(function(j,p){return '<div class="well">[&hellip;] '+$.trim(p)+' [&hellip;]</div>'}).get().join("")+'</li>');
      });
      if (d.results.length==25) {
        moreAllowed=true;
        $('.results').append('<li style="text-align:center" id="indicator" class="list-group-item"><span class="glyphicon glyphicon-refresh"></span> Suche nach weiteren Ergebnissen</li>')
      }
    }});
  }
  var handleBottomScroll=function(){
    if (!moreAllowed) return;
    getMore(); moreAllowed=false;
  }
  setInterval(function(){
    if (document.documentElement.scrollTop) currentScroll = document.documentElement.scrollTop;
    else currentScroll = document.body.scrollTop;
    totalHeight = Math.max(
      Math.max(document.body.scrollHeight, document.documentElement.scrollHeight),
      Math.max(document.body.offsetHeight, document.documentElement.offsetHeight),
      Math.max(document.body.clientHeight, document.documentElement.clientHeight)
    );
    visibleHeight = window.innerHeight || Math.max(document.body.clientHeight, document.documentElement.clientHeight);
    //console.log(totalHeight, currentScroll, visibleHeight);
    if (totalHeight <= currentScroll + visibleHeight + 250 ) handleBottomScroll();
  }, 250);
  $(window).resize(function(){ $.colorbox.resize({width:"100%",height:"100%"}); })
___
end

get "/results" do window=25
  results = @@index.search(index:params[:idx]||@@btl, q:params[:q]||"", from:[((params[:page]||"1").to_i-1)*window,0].max, size:25, body:{fields:["id","title","author"], highlight:{fields:{"content"=>{fragment_size:150, number_of_fragments:1000}}}, sort:[{"author.author_raw"=>"asc"},{"title.title_raw"=>"asc"},"_score"] })
  json hits:hits=results["hits"]["total"].to_i, pages:[(hits*1.0/window).ceil,1].max, results:results["hits"]["hits"].map{|h|f=h["fields"];[h["_id"],f["author"].first==""?"???":f["author"].first||"???",f["title"].first,(h["highlight"]||{})["content"]]}
end

get "/suggest/:input.json" do |input|
  word=input.split.first
  query=(0..5).map{|i| "#{word}#{"_"*i}" }.to_a.join(" ")
  suggestions = @@index.suggest(index:params[:idx]||@@btl, body:{"autocomplete"=>{text:query, term:{field:"content"}}})["autocomplete"].map{|s|s["options"]}.flatten(1).sort_by{|s|s["score"]}
  suggestions << {"text"=>word, "freq"=>@@index.count(index:params[:idx]||@@btl, body:{query:{term:{"content"=>word}}})["count"]}
  suggestions = suggestions.reverse.uniq{|s|s["text"]}.map{|s|{text:s["text"],docs:s["freq"]}}
  json suggestions
end

get "/termsearch" do
  hits=@@index.search(index:params[:idx]||@@btl, q:params[:q]||"", size:100000, body:{fields:[], highlight:{fields:{"content"=>{fragment_size:0, number_of_fragments:1000}}} })["hits"]["hits"]
  terms=Hash[hits.map{|h| h["highlight"]["content"].map{|c| c.match(/(?<=em>)(.*)(?=<\/em)/).to_a.first.downcase}}.flatten.group_by(&:to_s).map{|k,v|[k,v.count]}.sort_by(&:last).reverse]
  json terms
end

get "/document/:doc.json" do |doc|
  result = @@index.get(index:params[:idx]||@@btl, id:doc)["_source"]
  similar_list = @@index.mlt(index:params[:idx]||@@btl, id:doc, type:"work", mlt_fields:["content"])["hits"]["hits"]
  json author:result["author"]==""?"???":result["author"]||"???", title:result["title"], content:result["content_raw"].gsub("\n","\n<br />\n"), dating:result["dating"], similar:similar_list.map{|s|similar=s["_source"]; {label:"#{similar["author"]==""?"???":similar["author"]||"???"} - #{similar["title"]}", id:"#{s["_id"]}", score:s["_score"]}}.to_a.sort_by{|s|s[:score]}.reverse
end


@@css=<<_______
body { padding:0; padding-top: 64px; background-image: url(http://cdn.backgroundhost.com/backgrounds/subtlepatterns/concrete_wall_3.png);}
.navbar-inverse {background-image: url(http://cdn.backgroundhost.com/backgrounds/subtlepatterns/flowers.png); background-repeat:repeat;}
.well, pre.text, div.text {background-image: url(http://cdn.backgroundhost.com/backgrounds/subtlepatterns/ricepaper2.png); padding:1ex; margin:0.5ex; }
.result h3 { margin-top: 0; }
.result, pre.text, div.text { font-family: alegreya, serif; }
pre.text, div.text { font-size: 12pt; padding: 1em; margin: 1em; text-align:left; display:inline-block;}
#cboxLoadedContent { text-align:center; }
.result .well em, .querystring { background:rgba(66,139,202,0.25); padding:0.25ex; border-radius: 0.5ex; box-shadow: 0 0 2px rgba(66,139,202,0.25) }
.result { margin-bottom:1em; }
.results { margin-bottom:50px; font-feature-settings: "liga", "dlig"; -webkit-font-feature-settings: "liga", "dlig"; }
.result { display:list-item; }
#indicator { display:block; }
.list-group-item { border-radius: 1ex }
.twitter-typeahead .tt-query, .twitter-typeahead .tt-hint {  margin-bottom: 0; }
.tt-hint { display: none; }
.tt-dropdown-menu {
min-width: 160px;
margin-top: 3em;
padding: 5px 0;
background-color: #fff;
border: 1px solid #ccc;
border: 1px solid rgba(0,0,0,.2);
*border-right-width: 2px;
*border-bottom-width: 2px;
border-radius: 6px;
box-shadow: 0 5px 10px rgba(0,0,0,.2);
background-clip: padding-box;
}
.tt-suggestion { display: block; padding: 3px 20px; }
.tt-suggestion.tt-cursor, .tt-suggestion.tt-is-under-cursor, .tt-suggestion:hover { color: #fff; background-color: #0081c2; }
.tt-suggestion.tt-cursor a, .tt-suggestion.tt-is-under-cursor a, .tt-suggestion:hover a { color: #fff; }
.tt-suggestion p { margin: 0;}
.tt-hint { display: none; }
.twitter-typeahead { display:block !important; }
.twitter-typeahead pre { overflow:visible; }
.glyphicon-refresh { animation-name: rotateThis; animation-duration: .75s; animation-iteration-count: infinite; animation-timing-function: linear; }
@keyframes rotateThis { from { transform: scale( 1 ) rotate( 0deg ); } to { transform: scale( 1 ) rotate( 360deg ); } }
.text{ max-width:600px; overflow:visible; }
.path{ text-align: right; padding-right: 30px; margin-left: -1000px; width: 1000px; display: inline-block; float: left; overflow: hidden; height: 1.5em; opacity:.95; clear:both; }
.path:hover { background-color: rgba(255,255,0,0.25); border-top: 1px dotted rgba(255,0,0,0.6); box-shadow: 0 0.5em 2em rgba(255,255,0,0.25); border-radius: 0 0 1em 1em }
_______
__END__
@@ layout
%html
  %head
    %title=@title="BTL-Viewer"
    %link{href:"//cdnjs.cloudflare.com/ajax/libs/twitter-bootstrap/3.1.0/css/bootstrap.css", rel:"stylesheet"}
    %link{href:"//cdnjs.cloudflare.com/ajax/libs/jquery.colorbox/1.4.33/example5/colorbox.min.css", rel:"stylesheet"}
    %style=@@css
    %script{src:"//cdnjs.cloudflare.com/ajax/libs/jquery/1.11.0/jquery.min.js"}
    %script{src:"//cdn.jsdelivr.net/typeahead.js/0.10.1/typeahead.bundle.js"}
    %script{src:"//cdnjs.cloudflare.com/ajax/libs/jquery.colorbox/1.4.33/jquery.colorbox-min.js"}
    %script{src:"//cdnjs.cloudflare.com/ajax/libs/prefixfree/1.0.7/prefixfree.min.js"}
    %script{src:"//use.edgefonts.net/alegreya:n4,i4,n7,i7,n9,i9:all.js"}
  %body
    .navbar.navbar-inverse.navbar-fixed-top
      .container
        .navbar-header
          %a.navbar-brand
            %span.glyphicon.glyphicon-folder-open
            &nbsp;
            =@title
            ="(#{@@index.count(index:@@btl, type:"work")["count"]} Dokumente)"
        .collapse.navbar-collapse
    .container
      =yield
:javascript
  $('.query').typeahead({
    autoselect: false,
    minLength: 3,
    highlight: true
    },{
    displayKey: 'text',
    source: function(query, cb){if (query.split(/\s+/).length==1 && query.length>2) $.ajax("/suggest/"+query+".json", {success:function(d){ cb(d) } })},
    templates: {
      suggestion: function(o){return "<em>"+o["text"]+"</em>"+(o["docs"]>0?"<span style=\"float:right; width:"+(5*Math.log(o["docs"]+0.1))+"px; height:1.5em; border:1px solid rgba(255,255,255,0.5); border-radius: 2px; margin-top:-1px; background-color:rgb(49,126,172)\" title=\""+o["docs"]+"\"></span>":"")}
    }
  });
  $('.query').on('typeahead:selected', function(){search()})
