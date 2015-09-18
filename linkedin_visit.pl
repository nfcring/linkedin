#!/usr/bin/perl -w

use WWW::Mechanize;
my $mech = WWW::Mechanize->new();
my $url = 'https://www.linkedin.com/uas/login';
my $jar;
use HTTP::Cookies;
use LWP::UserAgent;
use POSIX;
use Data::Dumper;
use List::MoreUtils qw(uniq);
use IO::Handle;

my $split_page = 1;
if (@ARGV != 2){
    die("I need group id. Exiting");
}
if (@ARGV == 2){
    $split_page = $ARGV[1];
    print "Setting split_page=$split_page\n";
}

my $gid = $ARGV[0];

my %checkvisit=();

open FILE, "$ENV{HOME}/linkedin_users.txt" or die $!;
while(<FILE>){
    my ($usernr,$visitdate)=split(" ",$_);
    $checkvisit{$usernr}=$visitdate;
}
close FILE;
print "login: ";
my $login = <STDIN>;
print "Password: ";
system('/bin/stty', '-echo');  # Disable echoing
my $password = <STDIN>;
system('/bin/stty', 'echo');   # Turn it back on


my $ua = WWW::Mechanize->new(agent => 'Mozilla/5.0 (Windows NT 6.1; Win64; x64; rv:25.0) Gecko/20100101 Firefox/25.0');
$jar = HTTP::Cookies->new(file => "$ENV{HOME}/vaarekaker.txt",autosave => 1);
$ua->cookie_jar($jar);

my $loginpage = $ua->get($url);
$ua->set_fields("session_key" => $login, "session_password" =>$password );

my $login_response = $ua->submit();


#https://www.linkedin.com/groups?viewMembers=&gid=100569&sik=1392212763939&split_page=2
#https://www.linkedin.com/grp/members?gid=3054767
#https://www.linkedin.com/grp/members?gid=3054767&page=2

my %visited=();
my $pages=5;
my $count_visited_new = 0;
my $count_visited_before = 0;

open (MYFILE, ">>$ENV{HOME}/linkedin_users.txt");

MYFILE->autoflush;
for (my $page=$split_page;$page<$pages;$page++){
    my $gruppeurl = "https://www.linkedin.com/grp/members?gid=$gid";
    $ua->get($gruppeurl);
    my $result = $ua->content();
    
    if($result =~ m/class="member-count identified">([0-9,]+)\s+members<\/a>/){
	my $num_gr_members = join('', split(',',$1));
	$pages = ceil($num_gr_members/20);
	
#	my @links = $ua->find_all_links(url_regex => qr{/profile/view\?id=[^"]+anetppl_profile}); 
#
	my @links = $ua->find_all_links(url_regex => qr{/profile/view\?id=([A-Za-z0-9_]+)$}); 
	
	@urls = map { $_->url_abs()->full_path() } @links;
	
	my @uniq_links = uniq(@urls);
	for my $i (@uniq_links){
	    $i =~ m/id=(.*)&trk/g; #finds the user_id in url
	    
	    if(!defined($checkvisit{$i})){
		$count_visited_new++;
		print "+ Not visited before\n";
		print "[$count_visited_new] - Visiting url:https://www.linkedin.com$i\n";
		$visited{$i}=time();
		print MYFILE "$i $visited{$i}\n";
		print "Wrote $i $visited{$i} to file\n";
		$ua->get("https://www.linkedin.com$i");
		my $num = int (rand(15) +1);
		print "Sleeping $num seconds\n\n";
		sleep($num);
	    } else {
		print "- Visited before, finding next\n";
		$count_visited_before++;
	    }
	}
    }
}
close (MYFILE); 
print "Tot new visited, $count_visited_new\n";
print "Visited before, not again: $count_visited_before\n";
