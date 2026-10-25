path = ARGV.fetch(0)
text = File.read(path)

# 行末の「# @brief」「# @param」をDoxygenの後置コメントにする
text.gsub!(/[ \t]+#\s*#?@(?=brief\b|param\b)/, " ///< @")

# 行頭だけの「# @brief」「# #@brief」も変換する
text.gsub!(/^([ \t]*)#[ \t]*#?@(?=brief\b|param\b)/) do
  "#{Regexp.last_match(1)}/// @"
end

STDOUT.write(text)