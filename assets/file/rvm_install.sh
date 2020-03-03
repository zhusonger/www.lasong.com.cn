echo "Install RVM"
echo "---------------------------------------------------------------------------"
command gpg --keyserver hkp://keys.gnupg.net --recv-keys 409B6B1796C275462A1703113804BB82D39DC0E3
command curl -L https://get.rvm.io | bash -s stable
command source ~/.rvm/scripts/rvm

echo "ruby_url=https://cache.ruby-china.com/pub/ruby" > ~/.rvm/user/db

rvm requirements
rvm install 2.6.0 --disable-binary
rvm use 2.6.0 --default
rvm -v
ruby -v

gem sources --add https://gems.ruby-china.com/ --remove https://rubygems.org/
gem install bundler
bundle -v
echo "--------------------------- Install Successed -----------------------------"
