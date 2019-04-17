module Jira
  def self.get_valid_statuses
    {
      todo: "To Do",
      doing: "進行中",
      closed: "完了",
    }
  end

  class User
    attr_writer :email
    attr_writer :token
    attr_writer :boards
    attr_writer :board_ids
    attr_writer :epics
    attr_writer :epic_ids
    attr_writer :tickets

    require 'net/http'
    require 'uri'
    require "openssl"
    require "json"

    def initialize(email, token)
      @email = email
      @token = token
      @boards = []
      @board_ids = []
      @epics = []
      @epic_ids = []
    end

    def self.read_token(email, token)
      puts "JIRAアカウント情報を入力してください。" if email.nil? || email == "" || token.nil? || token == ""

      if email.nil? || email == ""
        print "email:"
        email = gets.chomp
      end

      if token.nil? || token == ""
        print "API token:"
        token = gets.chomp
      end

      if email == "" || token == ""
        puts "正しく入力してください。"
        read_token
      end

      self.new(email, token)
    end

    def get_boards
      url = URI.parse("https://sample.atlassian.net/rest/agile/latest/board")
      req = Net::HTTP::Get.new(url)
      req.basic_auth @email, @token

      response = Net::HTTP.start(url.host, url.port, use_ssl: url.scheme == 'https') do |http|
        http.request(req)
      end

      raise RuntimeError unless response.is_a?(Net::HTTPSuccess)

      @boards = JSON.parse(response.body)['values'].sort do |a, b|
        a['id'].to_i <=> b['id'].to_i
      end

      puts "ボードがありません" and return if @boards.empty?

      puts "=" * 40
      puts "ボード一覧"
      puts "-" * 40
      printf "%3s, %s\n", "id", "ボード名"
      puts "=" * 40

      @boards.each do |board|
        @board_ids << board['id'].to_i
        printf "%3s, %s\n", board['id'], board['location']['displayName']
      end
    end

    def read_board
      return nil if @boards.empty?

      print "ボードidを選択してください："
      b_id = gets.chomp.to_i

      return unless @board_ids.include?(b_id)

      b_id
    end

    def get_epics(board_id)
      url = URI.parse("https://sample.atlassian.net/rest/agile/latest/board/#{board_id}/epic")
      req = Net::HTTP::Get.new(url)
      req.basic_auth @email, @token

      response = Net::HTTP.start(url.host, url.port, use_ssl: url.scheme == 'https') do |http|
        http.request(req)
      end

      raise RuntimeError unless response.is_a?(Net::HTTPSuccess)

      @epics = JSON.parse(response.body)['values'].sort do |a, b|
        a['id'].to_i <=> b['id'].to_i
      end

      puts "エピックがありません" and return if @epics.empty?

      puts "=" * 40
      puts "エピック一覧"
      puts "-" * 40
      printf "%6s, %s\n", "id", "エピック名"
      puts "=" * 40

      @epics.each do |epic|
        @epic_ids << epic['id'].to_i
        printf "%6s, %s\n", epic['id'], epic['name']
      end
    end

    def read_epic
      return nil if @epics.empty?

      print "エピックidを選択してください："
      e_id = gets.chomp.to_i

      return unless @epic_ids.include?(e_id)

      e_id
    end

    def get_tickets(board_id, epic_id, statuses: %i( todo doing ))
      display_statuses = Jira.get_valid_statuses.values_at(*statuses)

      url = URI.parse("https://sample.atlassian.net/rest/agile/latest/board/#{board_id}/epic/#{epic_id}/issue")
      req = Net::HTTP::Get.new(url)
      req.basic_auth @email, @token

      response = Net::HTTP.start(url.host, url.port, use_ssl: url.scheme == 'https') do |http|
        http.request(req)
      end

      raise RuntimeError unless response.is_a?(Net::HTTPSuccess)

      @tickets = JSON.parse(response.body)["issues"].sort do |a, b|
        a['key'] <=> b['key']
      end

      puts "チケットがありません" and return if @tickets.empty?

      puts "=" * 40
      puts "チケット一覧"
      puts "-" * 40
      printf "%7s, %s, %2s, %s\n", "番号", "状態".mb_rjust(6, ' '), "SP", "チケット名"
      puts "=" * 40

      count = { all: 0 }
      sp_sum = { all: 0 }
      @tickets.each do |ticket|
        ticket_status = ticket["fields"]["status"]["name"]
        next unless display_statuses.include?(ticket_status)

        count[ticket_status.to_sym] = count[ticket_status.to_sym].to_i + 1
        count[:all] += 1

        sp = ticket["fields"]["customfield_10004"].to_i
        sp_sum[ticket_status.to_sym] = sp_sum[ticket_status.to_sym].to_i + sp
        sp_sum[:all] += sp

        printf "%7s, %s, %2s, %s\n", ticket["key"], ticket_status.mb_rjust(6, ' '), sp, ticket["fields"]["summary"]
      end

      puts "-" * 40
      puts "チケット合計：#{count[:all]}件"
      display_statuses.each do |s|
        printf " (内 %s：%2d件)\n", s.mb_rjust(6, ' '), count[s.to_sym]
      end
      puts "SP合計：#{sp_sum[:all]}"
      display_statuses.each do |s|
        printf " (内 %s：%2d)\n", s.mb_rjust(6, ' '), sp_sum[s.to_sym]
      end
    end
  end
end

class String
  # See https://www.techscore.com/blog/2012/12/25/ruby-%E3%81%A7%E3%83%9E%E3%83%AB%E3%83%81%E3%83%90%E3%82%A4%E3%83%88%E6%96%87%E5%AD%97%E3%81%AB%E5%AF%BE%E3%81%97%E3%81%A6-ljust-%E3%81%97%E3%81%A6%E3%82%82%E7%B6%BA%E9%BA%97%E3%81%AB%E6%8F%83/
  def mb_rjust(width, padding=' ')
    output_width = each_char.map{|c| c.bytesize == 1 ? 1 : 2}.reduce(0, &:+)
    padding_size = [0, width - output_width].max
    padding * padding_size + self
  end
end

def valid_id(id)
  if id.nil? || id == ""
    false
  else
    true
  end
end

def choice_display_status
  statuses = []
  available_statuses = Jira.get_valid_statuses.to_a

  puts ""
  puts "表示するチケット状態の番号を選択してください。複数選択の場合はカンマで区切ってください。未選択はすべて選択したことになります。"
  available_statuses.each_with_index do |s, idx|
    puts "[#{idx}] #{s[1]}"
  end
  print "=> "
  choices = gets.chomp.split(",").map(&:to_i).delete_if { |x| x >= available_statuses.length || x < 0 }
  statuses = available_statuses.values_at(*choices).map { |s| s[0] }
  statuses == [] ? available_statuses.map { |s| s[0] } : statuses
end

system("clear")
begin
  file = File.open("./token.txt", "r")
rescue
  puts "認証情報ファイル'token.txt'を準備してください。"
  return
end

email = ""
token = ""

file.each_line(chomp: true) do |line|
  key, *value = line.split("=")

  email = value.join("=") if key == "email"
  token = value.join("=") if key == "token"
end

file.close

jira_user = Jira::User.read_token(email, token)

jira_user.get_boards
b_id = jira_user.read_board
return "正しいidを選択してください。" unless valid_id(b_id)

jira_user.get_epics(b_id)
e_id = jira_user.read_epic
return "正しいidを選択してください。" unless valid_id(e_id)

statuses = choice_display_status
jira_user.get_tickets(b_id, e_id, statuses: statuses)
