Pakyow::Config.register(:server) { |config|

  # the port to start `pakyow server`
  config.opt :port, 3000

  # the host to start `pakyow server`
  config.opt :host, '0.0.0.0'

  # explicitly set a handler to try (e.g. puma)
  config.opt :handler

}
