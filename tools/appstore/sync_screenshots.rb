# App Store Connect のスクリーンショットを手元の内容に置き換える。
#
# fastlane の deliver は使わない。overwrite_screenshots がアップロード直後に
# 「反映されていない」と誤判定してリトライし、毎回二重に登録してしまうため。
# ここでは削除 → 反映待ち → アップロード → 検証を順番に行う。
#
#   bundle exec ruby tools/appstore/sync_screenshots.rb
require 'spaceship'

APP_IDENTIFIER = 'com.egi-engineer.Cookory'.freeze
DISPLAY_TYPE = 'APP_IPHONE_67'.freeze

# ディレクトリ名と ASC のロケール名の対応。
LOCALE_DIRS = { 'ja' => 'ja', 'en-US' => 'en-US' }.freeze

def screenshots_dir(locale)
  File.expand_path("../../fastlane/screenshots/#{locale}", __dir__)
end

def connect!
  Spaceship::ConnectAPI.token = Spaceship::ConnectAPI::Token.create(
    key_id: ENV.fetch('APP_STORE_CONNECT_KEY_ID'),
    issuer_id: ENV.fetch('APP_STORE_CONNECT_ISSUER_ID'),
    key: ENV.fetch('APP_STORE_CONNECT_API_KEY')
  )
end

def edit_version
  app = Spaceship::ConnectAPI::App.find(APP_IDENTIFIER)
  app.get_edit_app_store_version(platform: 'IOS') ||
    abort('編集可能なバージョンがありません。ASC でバージョンを作成してください。')
end

def each_set(version)
  version.get_app_store_version_localizations.each do |loc|
    next unless LOCALE_DIRS.key?(loc.locale)

    set = loc.get_app_screenshot_sets.find { |s| s.screenshot_display_type == DISPLAY_TYPE }
    yield loc, set
  end
end

def delete_all(version)
  each_set(version) do |loc, set|
    next if set.nil?

    shots = set.app_screenshots
    shots.each(&:delete!)
    puts "  [#{loc.locale}] 削除 #{shots.size} 件"
  end
end

# 削除は即座に反映されない。0 件になるまで待ってからアップロードする。
def wait_until_empty(version, timeout: 120)
  deadline = Time.now + timeout
  loop do
    remaining = 0
    each_set(edit_version) do |_loc, set|
      remaining += set.nil? ? 0 : set.app_screenshots.size
    end
    return true if remaining.zero?

    abort("削除の反映を #{timeout} 秒待ちましたが #{remaining} 件残っています。") if Time.now > deadline

    print "\r  反映待ち... 残り #{remaining} 件"
    sleep 5
  end
end

def upload_all(version)
  each_set(version) do |loc, set|
    dir = screenshots_dir(loc.locale)
    files = Dir.glob(File.join(dir, '*.png')).sort
    abort("#{dir} に PNG がありません。") if files.empty?

    set ||= loc.create_app_screenshot_set(attributes: {
      screenshotDisplayType: DISPLAY_TYPE
    })

    files.each do |path|
      print "  [#{loc.locale}] #{File.basename(path)} ... "
      set.upload_screenshot(path: path, wait_for_processing: true)
      puts 'OK'
    end
  end
end

def report(version)
  ok = true
  each_set(edit_version) do |loc, set|
    shots = set.nil? ? [] : set.app_screenshots
    names = shots.map(&:file_name)
    dupes = names.tally.select { |_, c| c > 1 }
    status = dupes.empty? ? '' : "  ← 重複: #{dupes.keys.join(', ')}"
    ok = false unless dupes.empty?
    puts "  [#{loc.locale}] #{shots.size}枚#{status}"
  end
  ok
end

connect!
version = edit_version
puts "バージョン: #{version.version_string} (#{version.app_store_state})"

puts "\n1. 既存のスクリーンショットを削除"
delete_all(version)

puts "\n2. 削除の反映を待つ"
wait_until_empty(version)
puts "\r  反映完了            "

puts "\n3. アップロード"
upload_all(edit_version)

puts "\n4. 検証"
if report(version)
  puts "\n完了しました。"
else
  abort("\n重複が残っています。もう一度実行してください。")
end
