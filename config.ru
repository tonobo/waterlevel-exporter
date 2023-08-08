require 'typhoeus'
require 'logger'
require 'ox'

LOGGER = Logger.new(STDERR)

FEEDS = {
  'Niederzwönitz / Zwönitz' => 'https://www.umwelt.sachsen.de/umwelt/infosysteme/hwims/portal/web/feed/wasserstand-pegel-564500',
  'Burkhardtsdorf 2 / Zwönitz' => 'https://www.umwelt.sachsen.de/umwelt/infosysteme/hwims/portal/web/feed/wasserstand-pegel-564505',
  'Altchemnitz 2 / Zwönitz' => 'https://www.umwelt.sachsen.de/umwelt/infosysteme/hwims/portal/web/feed/wasserstand-pegel-564531',
  'Chemnitz 1 / Chemnitz' => 'https://www.umwelt.sachsen.de/umwelt/infosysteme/hwims/portal/web/feed/wasserstand-pegel-564400'
}

$error_count = 0

METRIC = lambda do |name, value, station:, type: :gauge|
  <<~METRIC
    # TYPE #{name} #{type}
    waterlevel_#{name}{station=#{station.inspect}} #{value}
  METRIC
end


app = Rack::Builder.new do
  map '/metrics' do
    block = lambda do |env|
      status = 200
      metrics = []
      FEEDS.each do |station, link|
        response = Typhoeus.get(link)
        unless response.success?
          metrics << METRIC.call('error_count', $error_count += 1, station: station, type: :counter)
          LOGGER.error "[#{station}] Failed fetching feed data: #{response.inspect}"
          next
        end
        Ox.load(response.body).locate('*/item[0]').each do
          date = _1.locate('*/pubDate')&.first&.nodes&.first
          desc =_1.locate('*/description')&.first&.nodes&.first
          metrics << METRIC.call('lag_seconds', Time.now - Time.parse(date), station: station)
          metrics << METRIC.call('watermark_meters', desc[/Wasserstand: (\d+) cm/,1].to_f / 100, station: station)
          metrics << METRIC.call('flow_cubic_meters', desc[/Durchfluss: ([\d,]+)/, 1]&.tr(',', '.').to_f, station: station)
        end
      rescue StandardError => err
        metrics << METRIC.call('error_count', $error_count += 1, station: station, type: :counter)
        LOGGER.error "[#{station}] Unkown error occured: #{err} #{response.inspect}\n#{err.backtrace.join("\n")}"
        next
      end
      [
        status,
        { 'content-type' => 'text/plain' },
        StringIO.new(metrics.join)
      ]
    end
    run block
  end
end.to_app

run app

