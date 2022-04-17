# frozen_string_literal: true

require "json"
require "net/http"
require "open3"
require "pathname"
require "rbconfig"
require "time"
require "uri"
require "zlib"

require_relative "pandoc_binary/version"

module PandocBinary
  PREFIX = "pandoc"
  TOP_PATH = Pathname(__dir__).parent.expand_path
  LIBEXEC_PATH = TOP_PATH / "libexec"

  module RawDataParsable
    def from_raw_data(raw_data)
      return new(raw_data.slice(*members))
    end
  end

  module TimeAttributeParsable
    def define_time_attribute(name)
      define_method(:"#{name}_time") {
        Time.iso8601(public_send(name))
      }
    end
  end

  class Architecture < Struct.new(:name, :archive_suffix, :bin_path, :bin_suffix, keyword_init: true)
    def fetch_executable(version:, asset:)
      bin_path_in_archive = Pathname("#{PREFIX}-#{version}") / bin_path
      # super special case
      bin_path_in_archive = Pathname("pandoc-2.12/usr/bin/pandoc") if version == "2.12" && name == "linux-arm64"
      Open3.pipeline_r(
        [*%w[curl --silent --location], asset.browser_download_url],
        [*%w[bsdtar --to-stdout -xf -], bin_path_in_archive.to_s],
      ) do |stdout, wait_threads|
        result = yield(stdout)
        process_statuses = wait_threads.map(&:value)
        raise "Command failed with exit: statuses=#{process_statuses.inspect}" if !process_statuses.all?(&:success?)
        return result
      end
    end
  end

  ARCHITECTURES = [
    Architecture.new(name: "linux-amd64", archive_suffix: "tar.gz", bin_path: "bin/pandoc"),
    Architecture.new(name: "linux-arm64", archive_suffix: "tar.gz", bin_path: "bin/pandoc"),
    Architecture.new(name: "macOS", archive_suffix: "zip", bin_path: "bin/pandoc"),
    Architecture.new(name: "windows-x86_64", archive_suffix: "zip", bin_path: "pandoc.exe", bin_suffix: "exe"),
  ]

  class Release < Struct.new(:assets, :tag_name, :published_at, keyword_init: true)
    extend TimeAttributeParsable

    define_time_attribute :published_at

    class << self
      include RawDataParsable

      URI_BASE = "https://api.github.com/repos/jgm/pandoc/releases/tags/%{version}"

      def from_raw_data(raw_data)
        result = super
        result.assets = raw_data[:assets].map { |raw_asset|
          Asset.from_raw_data(raw_asset)
        }
        return result
      end

      def fetch_by_version(version)
        uri = URI(URI_BASE % {version: version})
        json = Net::HTTP.get(uri)
        raw_release = JSON.parse(json, symbolize_names: true)
        return from_raw_data(raw_release)
      end
    end

    class Asset < Struct.new(:name, :updated_at, :browser_download_url, keyword_init: true)
      extend RawDataParsable
      extend TimeAttributeParsable

      define_time_attribute :updated_at
    end

    def asset_by_architecture(architecture)
      return assets.find { |asset|
        asset.name.end_with?(architecture.archive_suffix) &&
          asset.name.index(architecture.name)
      }
    end
  end

  class << self
    NAME_TO_ARCHITECTURE = ARCHITECTURES.map { |architecture| [architecture.name, architecture] }.to_h

    def determine_architecture(host_os: RbConfig::CONFIG["host_os"], host_cpu: RbConfig::CONFIG["host_cpu"])
      case host_os
      when /linux/i
        case host_cpu
        when /amd64|x86_64|x64/i
          return NAME_TO_ARCHITECTURE["linux-amd64"]
        when /aarch64/i
          return NAME_TO_ARCHITECTURE["linux-arm64"]
        end
      when /darwin/i
        return NAME_TO_ARCHITECTURE["macOS"]
      when /mingw|mswin/i
        return NAME_TO_ARCHITECTURE["windows-x86_64"]
      end

      raise NotImplementedError, "This platform (#{host_os.inspect} #{host_cpu.inspect}) is not supported. Please send pull-request!"
    end

    def gzipped_executable_path(architecture: determine_architecture)
      return LIBEXEC_PATH / "#{PREFIX}-#{architecture.name}.gz"
    end

    def executable_path(architecture: determine_architecture)
      path = Pathname(
        ENV["PANDOC_BINARY_EXTRACTED_PATH"] ||
        LIBEXEC_PATH / "#{PREFIX}-#{architecture.name}"
      )
      path = path.sub_ext(".#{architecture.bin_suffix}") if architecture.bin_suffix
      return path if path.exist?

      gzipped_path = gzipped_executable_path(architecture: architecture)
      Zlib::GzipReader.open(gzipped_path) do |gzip|
        path.open("wb", 0o755) do |f|
          IO.copy_stream(gzip, f)
        end
      end
      return path
    end
  end
end
