require 'rouge'
require 'rouge/themes/github'

class ReviewDiffTheme < Rouge::Themes::Github
  name 'review-diff'
  style Generic::Inserted, bg: '#DDF4FF', inline_block: true, extend: true
  style Generic::Deleted, bg: '#FCE4EC', inline_block: true, extend: true
end
