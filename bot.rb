require 'telegram/bot'
require 'httparty'
require 'uri'
require 'yaml'

config = YAML.load_file('secrets.yml')
token = config['TOKEN']
$wikia_page = config['WIKIA_PAGE']
$bot_name = config['BOT_NAME']

def get_query_results(search_string)
  url = URI.escape("http://#{$wikia_page}.wikia.com/api/v1/Search/List/?query=#{search_string}&limit=10")
  response = HTTParty.get(url)
  response.parsed_response['items']
end

def get_article_info(id_list)
  return [] if id_list.empty?
  response = HTTParty.get("http://#{$wikia_page}.wikia.com/api/v1/Articles/Details/?ids=#{id_list.join(',')}&abstract=100")
  abstract_thumbnail_list = []
  id_list.each_with_index do |id, index|
    article = response['items'].values[index]
    if !(article.nil?)
      abstract_thumbnail_list.push(
        title: article['title'],
        abstract: article['abstract'],
        thumbnail: article['thumbnail'],
        url: "#{$wikia_page}.wikia.com#{article['url']}"
      )
    end
  end
  abstract_thumbnail_list
end

def create_inline_response(query)
  results_list = get_query_results(query)
  return [] if results_list.nil?
  result_id_list = results_list.map { |result| result['id'] }
  abstract_thumbnail_list = get_article_info(result_id_list)
  begin
    abstract_thumbnail_list.map.with_index do |item, i|
      Telegram::Bot::Types::InlineQueryResultArticle.new(
        id: i, title: item[:title], url: item[:url],
        message_text: item[:url], description: item[:abstract],
        thumb_url: item[:thumbnail]
      )
    end
  rescue
    []
  end
end

Telegram::Bot::Client.run(token) do |bot|
  begin
    bot.listen do |message|
      case message
      when Telegram::Bot::Types::InlineQuery
        results = create_inline_response(message.query)
        bot.api.answer_inline_query(inline_query_id: message.id, results: results)
      when Telegram::Bot::Types::Message
        bot.api.send_message(
          chat_id: message.chat.id, parse_mode: 'Markdown', text: "Please send an inline query to me! E.g. `@#{$bot_name} Main Character`"
        )
      end
    end
  rescue Telegram::Bot::Exceptions::ResponseError => e
    puts 'Telegram 502 error' if e.error_code.to_s == '502'
    retry
  rescue
    retry
  end
end
