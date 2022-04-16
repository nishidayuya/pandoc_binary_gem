# PandocBinary

## Installation

Install the gem and add to the application's Gemfile by executing:

```console
$ bundle add pandoc_binary
```

If bundler is not being used to manage dependencies, install the gem by executing:

```console
$ gem install pandoc_binary
```

## Usage

After installation, we can use `pandoc` command:

```console
$ pandoc --from=gfm --to=html5 a.md > /tmp/a.html
```

And we can use `PandocBinary.executable_path` to get `pandoc` command path:

```ruby
require "pandoc_binary"

p(PandocBinary.executable_path)
#=> #<Pathname:/home/yuya/.anyenv/envs/rbenv/versions/3.1.2/lib/ruby/gems/3.1.0/gems/pandoc_binary-2.10/libexec/pandoc-linux-amd64>
```

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/nishidayuya/pandoc_binary_gem .
