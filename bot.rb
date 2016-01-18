require 'telegram/bot'
require 'httparty'
require 'uri'

token = ENV["TAPI_TOKEN"]
$wikia_page = ENV["WIKIA_PAGE"]
$bot_name = ENV["BOT_NAME"]

def get_query_results(search_string)
  begin
    url = URI.escape("http://#{$wikia_page}.wikia.com/api/v1/Search/List/?query=#{search_string}&limit=10")
    response = HTTParty.get(url)
    response.parsed_response["items"]
  rescue Exception => e
    []
  end
end

def get_article_abstract_thumbnail(id)
  begin
    response = HTTParty.get("http://#{$wikia_page}.wikia.com/api/v1/Articles/Details/?ids=#{id}&abstract=100")
    item = response.parsed_response["items"]["#{id}"]
    return item['abstract'], item['thumbnail']
  rescue Exception => e
    return nil, nil
  end
end

def create_inline_response(results_list)
  return [] if results_list.nil?
  begin
    results_list.each_with_index.map do |result, i|
      abstract, thumbnail = get_article_abstract_thumbnail(result["id"])
      Telegram::Bot::Types::InlineQueryResultArticle.new(
        id: i, title: result["title"], url: result["url"],
        message_text: result["url"], description: abstract, thumb_url: thumbnail
      )
    end
  rescue Exception => e
    []
  end
end

Telegram::Bot::Client.run(token) do |bot|
  bot.listen do |message|
    case message
    when Telegram::Bot::Types::InlineQuery
      results = create_inline_response(get_query_results(message.query))
      bot.api.answer_inline_query(inline_query_id: message.id, results: results)

    when Telegram::Bot::Types::Message
      bot.api.send_message(
        chat_id: message.chat.id, parse_mode: "Markdown", text: "Please send an inline query to me! E.g. `@#{$bot_name} Main Character`"
      )
    end
  end
end
