require 'sinatra'
require 'oauth2'
require 'json'
require 'httparty'
require 'mini_magick'

$client = OAuth2::Client.new(ENV['CLIENT_ID'], ENV['CLIENT_SECRET'], :site => 'https://us.battle.net')

def get_token
  if !$token || $token.expired? then
    $token = $client.client_credentials.get_token
  end

  $token.token
end

def get_classes
  HTTParty.get("https://us.api.blizzard.com/wow/data/character/classes",
               :query => { "locale": "en_US" },
               :headers => { "Authorization": "Bearer #{get_token}" })['classes']
    .each_with_object({}) do |c, h|
    h[c["id"]] = c["name"]
  end
end

def get_character(name, realm)
  HTTParty.get("https://us.api.blizzard.com/wow/character/#{realm.downcase}/#{name.downcase}",
               :query => { "fields": "guild,items",
                           "locale": "en_US" },
               :headers => { "Authorization": "Bearer #{get_token}" })
end

def get_image(character)
  url = "https://render-us.worldofwarcraft.com/character/#{character["thumbnail"].sub("-avatar.jpg", "-inset.jpg")}"
  avatar = MiniMagick::Image.open(url)
  bg = MiniMagick::Image.open("./images/background-#{character["faction"]}.png")
  empty = MiniMagick::Image.open("./empty.png")

  sig = empty.composite(avatar) do |c|
    c.geometry("+2+2")
  end.composite(bg)

  sig.combine_options do |i|
    i.font("./fonts/merriweather/Merriweather-Bold.ttf")
    i.pointsize(30)
    i.fill("#deaa00")
    i.draw("text 220,40 '#{character["name"]}'")
    i.font("./fonts/merriweather/Merriweather-Regular.ttf")
    i.pointsize(12)
    i.fill("#888888")
    i.draw("text 220,65  'Level #{character["level"]} #{character["class_name"]} #{character["guild"] ? "of <" + character["guild"]["name"] + "> " : ""}on #{character["realm"]}'")
    i.draw("text 220,85  'Item Level: #{character["items"]["averageItemLevel"]} (#{character["items"]["averageItemLevelEquipped"]})'")
    i.draw("text 220,105 'Achievement Points: #{character["achievementPoints"]}'")
  end.to_blob
end

def get_signature(name, realm)
  character = get_character(name, realm)
  character["class_name"] = get_classes[character["class"]]
  get_image(character)
end

get '/:realm/:name' do |realm, name|
  content_type 'image/png'
  get_signature(name, realm)
end
