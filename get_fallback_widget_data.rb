require 'rest-client'
require 'json'
require 'csv'

load 'response_helper.rb'

FALLBACK_WIDGET_SLUGS = [
  "coupon", 
  "city-state-zip-search", 
  "self-storage-filtered", 
  "self-storage-search", 
  "multifamily-iui-cards-v2", 
  "multifamily-search-v2"
].sort.freeze

class LocationPageData
  attr_accessor :client_name, :location_name, :location_urn, :pages, :last_publish_date

  def initialize(client_name, location_name, location_urn, last_publish_date)
    @client_name = client_name
    @location_name = location_name
    @location_urn = location_urn
    @pages = ""
    @last_publish_date = last_publish_date
  end

  def display
    puts "#{client_name}"
    puts "#{location_name}"
    puts "#{location_urn}"
    puts "#{pages}"
    puts "#{last_publish_date}"
  end

  def add_page(page)
    if @pages
      @pages += page + ', '
    else 
      @pages = page
    end
  end

  def remove_last_comma
    @pages = @pages.chop.chop
  end
end

def build_cms_list(file_name, cms_holder)
  file = File.open(file_name, "r")
  while !file.eof?
    line = file.readline.chomp
    cms_holder.push(line)
  end
  file.close
end

def gather_cms_info(cms_list, cms_data_holder)
  cms_list.each do |cms|
    cms_url = "https://#{cms}.herokuapp.com/g5_ops/config.json"
    puts "Gathering data for #{cms}"
    response = get_response(cms_url)
    puts "Response => #{response}"
    json_data = get_data(response, cms_url) if response
    puts "data => #{json_data}" if json_data.empty?
    g5_internal = check_g5_internal(json_data) unless json_data.empty?
    puts "G5 Internal => #{g5_internal}"
    get_page_info(json_data, cms_data_holder) if g5_internal == false
  end
end

#check for g5_internal
def check_g5_internal(data)
  g5_internal = data["client"]["g5_internal"]
end

def get_page_info(data, cms_data_holder)
  client = data["client"]["name"]
  puts "Client => #{client}"
  first_location = data["locations"].first
  #puts "First location => #{first_location}"
  if first_location.nil?
    puts "First location empty"
    puts ""
  else
    data["locations"].each do |location|
      location_name = location["location"]
      puts "Location => #{location_name}"
      location_urn = location["urn"]
      puts "URN => #{location_urn}"
      last_publish_date = Date.parse(location["last_successful_deploy"]) unless location["last_successful_deploy"].nil?
      #puts "Publish date => #{last_publish_date}"
      location_data = LocationPageData.new(client, location_name, location_urn, last_publish_date)
      location["page_configs"].each do |page|
        page["garden_widget_slugs"].each do |widget_slug|
          if FALLBACK_WIDGET_SLUGS.include?(widget_slug)
            location_data.add_page(page["page"])
          end
        end
      end
    location_data.remove_last_comma
    cms_data_holder << location_data
    puts "Added #{location_name} data to holder!"
    puts ""
    end
  end
end

# script start
cms_list = []
cms_data_holder = []
puts "Starting script..."
file = "cms-list-test.txt"
build_cms_list(file, cms_list)
gather_cms_info(cms_list, cms_data_holder)
puts "CMS holder => #{cms_data_holder}"
