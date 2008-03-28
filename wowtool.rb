#!/usr/bin/env ruby

# =========================================
# = World of Warcraft Character Info Tool =
# =========================================
# 
#   Grabs data from the WoW Armory.
# 
# =========================================

require 'rexml/document'
require 'net/http'
require 'optparse'
require 'ostruct'
require 'cgi'
require 'yaml'

# Colorizes text if CLICOLOR is defined in the environment.
def colorize(text, color_code)
  ENV.include?("CLICOLOR") ? "#{color_code}#{text}\e[0m" : text
end

def white(text); colorize(text, "\e[37m"); end
def red(text); colorize(text, "\e[31m"); end
def green(text); colorize(text, "\e[32m"); end
def yellow(text); colorize(text, "\e[33m"); end

# End color stuff

# module WorldOfWarcraft
  class Character
    attr_accessor :realm, :battle_group, :cclass, :faction, :gender, :guild
  
    def initialize(level, race, name, realm, battle_group, cclass, faction, gender, guild, title = nil)
      @realm = realm
      @battle_group = battle_group
      @cclass = cclass.downcase.to_sym
      @faction = faction.downcase.to_sym
      @gender = gender.downcase.to_sym
      @guild = guild
      @title = title
      @level = level.to_i
      @race = race
      @name = name
    end
  
    def inspect
      "#{@name} %sis a level #{@level} #{@gender.to_s.capitalize} #{@race} #{@faction.to_s.capitalize} #{@cclass.to_s.capitalize} on #{@realm} in battle group #{@battle_group}." %
        [@guild != nil ? "<#{@guild}> " : ""]
    end
  end

  class Realm
    
    attr_accessor :name, :up, :language, :type, :queue
    
    @@languages = [:en, :de, :fr, :es]
    
    def initialize(name, status, type, queue, language=:en)
      @name = name
      if(status == "Up" || status == true || status == "Realm Up") then
        @up = true
      else
        @up = false
      end
      @language = language.to_sym
      @type = type
      if(queue == true || queue == "true") then
        @queue = true
      else
        @queue = false
      end
    end
    
    def inspect
      "#{white(@name.ljust(24, "."))}(#{@language}) #{type.ljust(6)} is #{@up ? green("UP") : red("DOWN")} #{@queue ? yellow("Queue") : "NoQueue"}"
    end
    
  end

  # Returns a REXML::Document for the specified
  # character on the specified realm.
  def load_character_xml(realm, name)
    http = Net::HTTP.new('eu.wowarmory.com', 80)
    path = "/character-sheet.xml?r=#{realm}&n=#{name}"
    headers = {
      'User-agent' => 'Firefox/2.0.0.1'
    }
    resp = http.get(path, headers)

    xmldoc = REXML::Document.new(resp.body)
  end

  def show_char_info(realm, char, yaml=false)
    xmldoc = load_character_xml(realm, char)
    xmldoc.each_element("/page/characterInfo/character") do |char|
      theChar = Character.new(
        char.each_element("@level")[0].to_s,
        char.each_element("@race")[0].to_s,
        char.each_element("@name")[0].to_s,
        char.each_element("@realm")[0].to_s,
        char.each_element("@battleGroup")[0].to_s,
        char.each_element("@class")[0].to_s,
        char.each_element("@faction")[0].to_s,
        char.each_element("@gender")[0].to_s,
        char.each_element("@guildName")[0].to_s
      )
      unless yaml
        puts theChar.inspect
      else
        puts theChar.to_yaml
      end
    end
  end

  def show_realm_status(realm = nil, yaml=false)
    http = Net::HTTP.new('www.wow-europe.com', 80)
    path = "/en/serverstatus/index.xml"
    headers = {
      'User-agent' => 'Firefox/2.0.0.1'
    }
    resp = http.get(path, headers)
    xmldoc = REXML::Document.new(resp.body)
    if(realm == nil) then # Show status for all realms
      puts "Status of all realms:"
      xmldoc.each_element("/rss/channel/item") do |el|
        if(el.get_elements("category[@domain='type']").size > 0) then
          r = Realm.new(
            CGI::unescapeHTML(el.get_elements("title")[0].get_text.to_s),
            CGI::unescapeHTML(el.get_elements("category[@domain='status']")[0].get_text.to_s),
            CGI::unescapeHTML(el.get_elements("category[@domain='type']")[0].get_text.to_s),
            CGI::unescapeHTML(el.get_elements("category[@domain='queue']")[0].get_text.to_s),
            CGI::unescapeHTML(el.get_elements("category[@domain='language']")[0].get_text.to_s)
          )
          unless yaml then
            puts "\t#{r.inspect}"
          else
            puts r.to_yaml
          end
        else
          # Not a realm element
          
        end
      end
    else
      # We know what realm to check
      matches = xmldoc.get_elements("/rss/channel/item[title='#{realm.capitalize}']")
      if(matches.size > 0) then 
        matches.each do |r|
          rr = Realm.new(
            CGI::unescapeHTML(r.get_elements("title")[0].get_text.to_s),
            CGI::unescapeHTML(r.get_elements("category[@domain='status']")[0].get_text.to_s),
            CGI::unescapeHTML(r.get_elements("category[@domain='type']")[0].get_text.to_s),
            CGI::unescapeHTML(r.get_elements("category[@domain='queue']")[0].get_text.to_s),
            CGI::unescapeHTML(r.get_elements("category[@domain='language']")[0].get_text.to_s)
          )
          
          unless yaml then
            puts "\t#{rr.inspect}"
          else
            puts rr.to_yaml
          end
        end
      else
        puts "No matching realms!"
      end
    end
  end

  # Begin option-parsing stuff
  options = OpenStruct.new
  options.realm = nil
  options.char = nil
  options.yaml_output = false
  options.check_realm_status = false
  optp = OptionParser.new do |opts|
    opts.banner = "Usage: #{$0} [options]"

    opts.separator ""
    opts.separator "Filtering Options:"

    opts.on("-r", "--realm REALM", "Filter by REALM (req. for character/guild info)") do |rlm|
      options.realm = rlm
    end

    opts.on("-c", "--character NAME", "Grab details for the character NAME") do |char|
      options.mode = :char_info
      options.char = char
    end
  
    opts.on("-s", "--status", "Display the status of a realm.") do |s|
      options.check_realm_status = true
    end
    
    opts.separator ""
    opts.separator "Common Options:"
    
    opts.on_tail("-y", "--yaml", "Provide yaml output") do |y|
      options.yaml_output = true
    end
    
    opts.on_tail("-h", "--help", "Show this help message.") do |v|
      puts opts
      options.show_help = true
      # exit
    end
  end
  begin
    optp.parse!
  rescue Exception => e
    puts "Error - #{e}!", "", optp
    exit
  end
  if options.show_help then
    exit
  elsif(options.realm) then
    if(options.char) then
      show_char_info(options.realm, options.char, options.yaml_output)  
    elsif options.check_realm_status
      puts "Getting realm status for #{options.realm}."
      show_realm_status(options.realm, options.yaml_output)
    else
      puts "I don't know what you want me to find out about #{options.realm.capitalize}!", "", optp
    end
  elsif(options.check_realm_status) then
    show_realm_status(options.realm, options.yaml_output)
  else
    if options.char then 
      puts "You need to choose a realm!", "", optp
      exit
    end
    puts "I don't know what you want me to do!", "", optp
  end
  # End option-parsing stuff
# end