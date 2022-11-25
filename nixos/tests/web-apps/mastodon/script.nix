{ extraInit ? ""
, extraShutdown ? ""
}:


''
start_all()

${extraInit}

ca.wait_for_unit("step-ca.service")
ca.wait_for_open_port(8443)

# Check that mastodon-media-auto-remove is scheduled
server.succeed("systemctl status mastodon-media-auto-remove.timer")

server.wait_for_unit("nginx.service")
server.wait_for_unit("redis-mastodon.service")
server.wait_for_unit("postgresql.service")
server.wait_for_unit("mastodon-sidekiq.service")
server.wait_for_unit("mastodon-streaming.service")
server.wait_for_unit("mastodon-web.service")
server.wait_for_open_port(55000)
server.wait_for_open_port(55001)

# Check Mastodon version from remote client
client.succeed("curl --fail https://mastodon.local/api/v1/instance | jq -r '.version' | grep '${pkgs.mastodon.version}'")

# Check access from remote client
client.succeed("curl --fail https://mastodon.local/about | grep 'Mastodon hosted on mastodon.local'")
client.succeed("curl --fail $(curl https://mastodon.local/api/v1/instance 2> /dev/null | jq -r .thumbnail) --output /dev/null")

# Check using admin CLI
# Check Mastodon version
server.succeed("su - mastodon -s /bin/sh -c 'mastodon-env tootctl version' | grep '${pkgs.mastodon.version}'")

# Manage accounts
server.succeed("su - mastodon -s /bin/sh -c 'mastodon-env tootctl email_domain_blocks add example.com'")
server.succeed("su - mastodon -s /bin/sh -c 'mastodon-env tootctl email_domain_blocks list' | grep 'example.com'")
server.fail("su - mastodon -s /bin/sh -c 'mastodon-env tootctl email_domain_blocks list' | grep 'mastodon.local'")
server.fail("su - mastodon -s /bin/sh -c 'mastodon-env tootctl accounts create alice --email=alice@example.com'")
server.succeed("su - mastodon -s /bin/sh -c 'mastodon-env tootctl email_domain_blocks remove example.com'")
server.succeed("su - mastodon -s /bin/sh -c 'mastodon-env tootctl accounts create bob --email=bob@example.com'")
server.succeed("su - mastodon -s /bin/sh -c 'mastodon-env tootctl accounts approve bob'")
server.succeed("su - mastodon -s /bin/sh -c 'mastodon-env tootctl accounts delete bob'")

# Manage IP access
server.succeed("su - mastodon -s /bin/sh -c 'mastodon-env tootctl ip_blocks add 192.168.0.0/16 --severity=no_access'")
server.succeed("su - mastodon -s /bin/sh -c 'mastodon-env tootctl ip_blocks export' | grep '192.168.0.0/16'")
server.fail("su - mastodon -s /bin/sh -c 'mastodon-env tootctl p_blocks export' | grep '172.16.0.0/16'")
client.fail("curl --fail https://mastodon.local/about")
server.succeed("su - mastodon -s /bin/sh -c 'mastodon-env tootctl ip_blocks remove 192.168.0.0/16'")
client.succeed("curl --fail https://mastodon.local/about")

ca.shutdown()
server.shutdown()
client.shutdown()

${extraScript}
''
