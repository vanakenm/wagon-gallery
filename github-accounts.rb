require 'nokogiri'
require 'open-uri'
require 'json'
require 'base64'
require 'webshot'
require 'webrick'

GITHUB_TOKEN = "yourtokenhere" # get one at https://github.com/settings/applications - generate new token. Just ask for "public_repo" auth

class GalleryGenerator
  attr_reader :users

  def initialize(users)
    @users = users
  end

  def generate_folders(challenge)
    Dir.mkdir("sites")
    users.each do |user| 
      Dir.mkdir("sites/#{user}")
      collect_dir(user, "/fullstack-challenges/contents/#{challenge}")
    end
  end

  def generate_thumbs
    server = WEBrick::HTTPServer.new :Port => 8000, :DocumentRoot => "sites"

    trap 'INT' do 
      server.shutdown 
    end

    Thread.new do
      server.start
    end

    Webshot.capybara_setup!
    Dir.mkdir("sites/images") unless File.exists?("sites/images")


    users.each do |user|
      unless File.exists?("sites/images/#{user}.png")
        begin
          url = "http://localhost:8000/#{user}/index.html"
          webshot = Webshot::Screenshot.instance
          webshot.capture url, "sites/images/#{user}.png"
        rescue
          puts "No image for #{user}"
        end
      end
    end

    server.stop
  end

  def generate_index
  f = File.open("template.html")
  doc = Nokogiri::HTML(f)
  f.close

  row = doc.at_css ".row"
  users.each do |user| 
    image_url = File.exists?("sites/images/#{user}.png") ? "images/#{user}.png" : "http://placehold.it/120x90"
    user_node = "<div class='col-xs-4'><h3>#{user}</h3><a href='#{user}/index.html'><img src='#{image_url}'></a></div>"
    row << user_node
  end

  index = File.open("sites/index.html","wb") { |f| f.write(doc.to_html) }
end

  private

  def collect_dir(github_user, base, dir_name = "")
    url = "https://api.github.com/repos/#{github_user}#{base}#{dir_name}?access_token=#{GITHUB_TOKEN}"
    puts "Opening: #{url}"
    dir = JSON.parse(open(url).read)
    dir.each do |file|
      if(file["type"] == "dir")
        Dir.mkdir("sites/" + github_user + dir_name + "/" + file["name"]) unless File.exists?(github_user + "/" + file["name"])
        new_dir = dir_name + "/" + file["name"]
        collect_dir(github_user, base, new_dir)
      else
        content = open(file["download_url"]).read
        name = file["name"]
        File.open("sites/#{github_user}#{dir_name}/#{name}", "wb") { |f| f.write(content) }
      end
    end
  end
end

def get_users
  url = "http://kitt.lewagon.org/camps/7/dashboard"
  content = Nokogiri::HTML(open("dash.html"))

  links = content.css("th > a")
  links.map { |link| link.attr("href").split("/").last }
end

generator = GalleryGenerator.new(get_users)
#generator.generate_folders("04-Front-End/02-Bootstrap/04-Bootstrap-mockup-v2")
#generator.generate_thumbs
generator.generate_thumbs
