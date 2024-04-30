require "sinatra"
require "sinatra/reloader"
require "http"
require "sinatra/cookies"

get("/") do
 "Howdy"
end

get("/umbrella") do
  erb(:umbrella_form)
end

post("/process_umbrella") do
  @user_loc = params.fetch("user_location")
  gmaps_url = "https://maps.googleapis.com/maps/api/geocode/json?address=#{@user_loc}&key=#{ENV.fetch("GMAPS_KEY")}"
  @raw_loc = HTTP.get(gmaps_url.to_s)
  
  parsed_location_url = JSON.parse(@raw_loc)
#pp parsed_location_url

results_hash = parsed_location_url.fetch("results")
#pp geometry_hash

geometry_array = results_hash.at(0)
#pp geometry_array

geometry_hash = geometry_array.fetch("geometry")
#pp geometry_hash

location_hash = geometry_hash.fetch("location")
#pp location_hash

@lat = location_hash.fetch("lat")
@lng = location_hash.fetch("lng")
#pp "#{lat} #{lng}"

pirate_weather_key = ENV.fetch("PIRATE_WEATHER_KEY")
pirate_weather_url = "https://api.pirateweather.net/forecast/#{pirate_weather_key}/#{@lat},#{@lng}"

raw_pirate_weather_url = HTTP.get(pirate_weather_url)
parsed_pirate_weather_url = JSON.parse(raw_pirate_weather_url)
#pp parsed_pirate_weather_url

currently_hash = parsed_pirate_weather_url.fetch("currently")
#pp currently_hash

@current_temp = currently_hash.fetch("temperature")
#pp "The current temperatue is: #{current_temp}"

@current_summary = currently_hash.fetch("summary")
#pp " The current situation is: #{current_summary}"

# Next hour summary
minutely_hash = parsed_pirate_weather_url.fetch("minutely")
if minutely_hash 
  next_hour_summary = minutely_hash.fetch("summary")
 # pp "The next hour situation is: #{next_hour_summary}"
end

# Next 12 hours summary
hourly_hash = parsed_pirate_weather_url.fetch("hourly")
hourly_data_array = hourly_hash.fetch("data")
next_twelve_hours = hourly_data_array[1..12]
precip_prob_threshold = 0.10
any_precp = false

next_twelve_hours.each do |x|
   precip_prob = x.fetch("precipProbability")
   #pp x

   if precip_prob > precip_prob_threshold
    any_precp = true
    precip_time = Time.at(x.fetch("time"))
    seconds = precip_time - Time.now
    hours = seconds / 60 / 60
    #pp "In #{hours.round} from now, There is a chance of #{precip_prob * 100} % of precipitation probability"
   end  

  end

if any_precp == true
  @result = "You might want to carry an umbrella!"
else
  @result = "You probably won’t need an umbrella today."
end

  erb(:umbrella_results)
end


get("/message") do
  erb(:message_form)
end

post("/process_single_message") do

@my_message = params.fetch("the_message")

# Prepare a hash that will become the headers of the request
request_headers_hash = {
  "Authorization" => "Bearer #{ENV.fetch("OPENAI_API_KEY")}",
  "content-type" => "application/json"
}

# Prepare a hash that will become the body of the request
request_body_hash = {
  "model" => "gpt-3.5-turbo",
  "messages" => [
    {
      "role" => "system",
      "content" => "You are a helpful assistant who talks like Shakespeare."
    },
    {
      "role" => "user",
      "content" => "#{@my_message}"
    }
  ]
}

# Convert the Hash into a String containing JSON
request_body_json = JSON.generate(request_body_hash)

# Make the API call
raw_response = HTTP.headers(request_headers_hash).post(
  "https://api.openai.com/v1/chat/completions",
  :body => request_body_json
).to_s

# Parse the response JSON into a Ruby Hash
parsed_response = JSON.parse(raw_response)
@parsed_hash = parsed_response.fetch("choices").at(0).fetch("message").fetch("content")


erb(:message_results)

end


get("/chat") do
  erb(:chat_form)
end

post("/add_message_to_chat") do
  
  @my_message = params.fetch("user_message")
  cookies["chat_history"].push = @my_message
  # Prepare a hash that will become the headers of the request
  request_headers_hash = {
    "Authorization" => "Bearer #{ENV.fetch("OPENAI_API_KEY")}",
    "content-type" => "application/json"
  }

  # Prepare a hash that will become the body of the request
  request_body_hash = {
    "model" => "gpt-3.5-turbo",
    "messages" => [
      {
         "role" => "system",
         "content" => "You are a helpful assistant who talks like Shakespeare."
      },
      {
        "role" => "user",
        "content" => "#{@my_message}"
      }
    ]
  }

  # Convert the Hash into a String containing JSON
  request_body_json = JSON.generate(request_body_hash)

  # Make the API call
  raw_response = HTTP.headers(request_headers_hash).post("https://api.openai.com/v1/chat/completions",:body => request_body_json).to_s

  # Parse the response JSON into a Ruby Hash
  parsed_response = JSON.parse(raw_response)
  @parsed_hash = parsed_response.fetch("choices").at(0).fetch("message").fetch("content")
  cookies["chat_history"].push = @parsed_hash
  erb(:chat_results)
end
