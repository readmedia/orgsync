# Orgsync

A simple API wrapper for the OrgSync API.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'orgsync'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install orgsync

## Usage

```ruby
API_KEY = "<orgsync-api-key>"

# Get all clubs or activities (OrgSync calls these Organizations)
org_list = OrgSync::Organization.find(:all, {}, API_KEY)
org_list.each do |org|

  # Get all members of this organization (OrgSync calls these Accounts)
  org.accounts.each do |acct|
  
    # Get all join and leave events for this member in this organization (OrgSync's Membership Logs)
    acct.membership_logs.each do |log|
      # ...
    end
  end
end
```

See `example.rb` for a script that retrieves all clubs and activities, and generates rosters for those activities.

## Contributing

1. Fork it ( https://github.com/[my-github-username]/orgsync/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request


## Archived
This repository was archived on 2022-07-08 since it is no longer in development, has never been forked, and is no longer used by the author(s).
