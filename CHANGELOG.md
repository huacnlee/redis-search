## 0.9.6 / 2014-4-1

  * Performance improve for create index (2.7x faster than previous, [Benchmark results](https://gist.github.com/huacnlee/9907235)). 
  * Refactor codes.
  * Require redis gem version upto 3.0.0+;

## 0.9.5 / 2014-2-17

  * Fix an index clean bug;
  * Fix bug on alias value is nil;

## 0.9.4 / 2014-2-11

  * Fix bug for save faild when title it was nil.

## 0.9.3 / 2014-2-11

  * Fix words split bug.

## 0.9.2 / 2014-1-14

  * ruby-pinyin with autoload.

## 0.9.1 / 2013-12-30

  * Add polyphone support, use [ruby-pinyin](https://github.com/janx/ruby-pinyin) to instead [chinese_pinyin](https://github.com/flyerhzm/chinese_pinyin);

## 0.9.0 / 2012-07-20

  * New feature or Search as Pinyin first chars.

## before 0.8.0

  * Real-time search
  * High performance
  * Segment words search and prefix match search
  * Support match with alias
  * Support ActiveRecord and Mongoid
  * Sort results by one field
  * Homophone search, pinyin search
  * Conditions support
