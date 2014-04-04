# Perl script
# History:
#   Dec 13th, 2010: Add main list getting feature.
#   Nov 16th, 2010: Added Prompt option in .ini file. To prompt after each updating. 1:update single 0:update all.
#   Sep 2th, 2009: Added utf8 encoding on description file generation.
#   Dec 4th, 2008: Added proxy support.
#   Jun 9th, when parse fail, continu to next loop. when finding "wTt wT$resolution_width"

use Win32::Internet;
use Win32::Console;

use HTML::Parser;
use HTML::TreeBuilder;
use Config::IniFiles; # need to install Config::IniFiles.
use strict;
use Cwd;
use Encode;
use Getopt::Std;

my $g_con_output = Win32::Console->new(STD_OUTPUT_HANDLE) or die $!;
my $g_con_input = Win32::Console->new(STD_INPUT_HANDLE) or die $!;


our ($opt_a, $opt_i);
my $is_debug = 1; # switch of debug or normal using.

getopts('ai'); 
if($opt_a && $opt_i){
    print "-a and -i cannot be used at the same time.\n";
}elsif($opt_a){
    print "Getting the make list...\n";
}elsif($opt_i){
    print "Getting the updates...\n";
}else{
    print "-a means get the main list\n";
    print "-i means get the update list\n";
    exit;
}

my $version = "101213";

print "version ", $version, "\n";

my $DOMAIN = "www.netcarshow.com";

my $ini_file_path = "update.ini";

my $cfg = new Config::IniFiles( -file => $ini_file_path,
				-commentchar => ';') or die $!;

my $resolution = $cfg->val( "options", "resolution");
my ($resolution_width, $resolution_height) = split(/x/, $resolution);

my @dl = $cfg->val("history", "dl");
my $last = $cfg->val( "options", "last");
my $proxy = $cfg->val("options", "proxy");
my $user = $cfg->val("options", "user");
my $pass = $cfg->val("options", "pass");
my $prompt = $cfg->val("options", "prompt");
my $store_dir = $cfg->val("options", "store_dir");

if($is_debug){
    print "The value is " . $cfg->val( 'Section', 'Parameter' ) . "." if $cfg->val( 'Section', 'Parameter' );
}

my $INET;
if ($proxy){
    $INET = new Win32::Internet("Mozilla/3.0", INTERNET_OPEN_TYPE_PROXY, $proxy) or die "Error on Win32::Internet(): $!\n"; 
}else{
    $INET = new Win32::Internet(); 
}

my $statuscode, my $headers, my $file;

my $HTTP;
$INET->HTTP($HTTP, $DOMAIN, $user, $pass) or die "Error on HTTP request: $!";


my %makes = ();
my @make_names = ();
my @titles = ();

my $tree = HTML::TreeBuilder->new;
if($opt_a){
    # To get the main makes list.
    select STDOUT; $| = 1;
    if(0 == $is_debug){
	($statuscode, $headers, $file) = $HTTP->Request("/"); 
	$HTTP->Close();
	$tree = $tree->parse_content($file);
    }else{
	$tree = $tree->parse_file("make.htm");
    }

    @titles = $tree->find_by_tag_name('li');
    
    my $index = 0;
    my $new_index = 0;

    foreach (@titles){
	if($_->as_text() =~ /\(/){
	    next;
	}
	my $link, my $element, my $attr, my $tag;
	for (@{$_->extract_links('a')}) {
	    ($link, $element, $attr, $tag) = @$_;
	}
	
	$makes{$_->as_text()} = $link;
    }
    
    my $sep;

    $index = 0;
    foreach my $key (sort {myfunction($a,$b)} keys %makes){
#	print "$key => $makes{$key}\n";
	$make_names[$index] = $key;
	$index++;
    }
    
    my %cnt;
    $cnt{"make"} = @make_names;
    my %prompt;
    $prompt{"make"} = "Please input option(0 - " . ($cnt{"make"} - 1). "):";
    $prompt{"model"} = "Please use SPACE bar to select the model you want to download or type a to download them all.";
    
    my $input;

    &display_make;

    print STDOUT $prompt{"make"};


    while(<>){	
	chomp $_;
	$_ = uc $_;
	
	if(length $_ == 0){
	}elsif($_ eq "Q"){
	    last;
	}elsif((int $_) >= 0 && (int $_) <= $cnt{"make"}){
	    my $make_name = $make_names[int $_];
	    print $make_name, " -> ", $makes{$make_name}, "\n";

	    ($statuscode, $headers, $file) = $HTTP->Request($makes{$make_name}); 
	    $tree = $tree->parse_content($file);
	    @titles = $tree->find_by_tag_name('li');
	    
	    my $model_index = 0;
	    my $model_new_index = 0;
	    my %models = ();
	    foreach (@titles){
		if($_->as_text() !~ /^\d{4}/){
		    next;
		}
		
		my $link, my $element, my $attr, my $tag;
		for (@{$_->extract_links('a')}) {
		    ($link, $element, $attr, $tag) = @$_;
		}
		
		print $_->as_text(), "->", $link, "\n";		    
		dl_style($_->as_text(), $link, $store_dir . "/" . $make_name);
		print "\n";
	    }
	}
	&display_make;

	print STDOUT $prompt{"make"};
    }
    
}elsif($opt_i){
    print STDOUT "Getting the update lists...\n";
    ($statuscode, $headers, $file) = $HTTP->Request("/updates.html"); 
#print $file;
    select STDOUT; $| = 1;
    
    $tree = HTML::TreeBuilder->new;
    $tree = $tree->parse_content($file);
    
    @titles = $tree->find_by_tag_name('li');
    
    my @styles = ();
    my @styles_links = ();
    my $i = 0;
    
    my $link, my $element, my $attr, my $tag;
# Get style names and links:
    foreach my $title (@titles){
	for (@{$title->extract_links('a')}) {
	    ($link, $element, $attr, $tag) = @$_;
	}
	
	$styles[$i] = $title->as_text();
	$styles_links[$i] = $link;
	$i++;
	print $title->as_text(), "--", $link, "\n";
    }
    
    my $style_index = 0;
    my $dir, my $date;  # store date/dir;
    my $statuscode, $headers, $file;
    my $tree, @titles;
    my $pic_name;
# the big loop to get them each:
    for($style_index = 0; $style_index < @styles; $style_index++){
	@titles = ();
	print "\nGetting ", $styles[$style_index], "...\n";
	$dir = $styles[$style_index];
	$dir =~ s/\(?(\d+)-?(\d+)-?(\d+)\)\s//;
	$date = $1 . "-" . $2 . "-" . $3;
	
	if(check_dl($date . "/" . $dir, \@dl, $last) eq 1){
	    next;
	}else{
	    mkdir $date, 0755;
	}

	dl_style($dir, $styles_links[$style_index], $date);

	$cfg->setval("options", "last", $date . "/" . $dir);
	$cfg->WriteConfig($ini_file_path);
	
	$cfg->setval("options", "last", "");
	@dl = (@dl, "$date/$dir");
	$cfg->setval("history", "dl", @dl);
	$cfg->WriteConfig($ini_file_path);
	
      PROMPT:
	if($prompt eq "1"){
	    print "Do we continue?<y/n/q>:";
	    my $c = <>;
	    chomp $c;
	    $c = uc $c;
	    if($c eq "Y"){
#	print "YES accepted\n";
		next;
	    }elsif($c eq "N" or $c eq "Q"){
#	print "$c accepted\n";
		last;
	    }else{
		print "$c accepted\n";
		goto PROMPT;
	    }
	}
    }
}
$tree->delete;
$HTTP->Close();

# check_dl ($style2check, @list, $exclude);
sub check_dl{
    
    my $style2check = shift;
    my $list = shift;
    my @list = @$list;
    
    my $exclude = shift;
    
    foreach my $check (@list){
	if($check eq $style2check){
	    if($check eq $exclude){
		# this style is not finished yet
		return 0;
	    }
	    return 1;
	}
    }
    return 0;
}

sub myfunction
{
    return (shift(@_) cmp shift(@_));
}

sub display_make
{
    my $index = 0;
    my $sep;
    foreach (@make_names){
	if($index ne 0 && ($index + 1) % 5 eq 0){
	    $sep = "\n";
	}else{
	    $sep = "\t";
	}
	printf "%3d.%13s%s", $index, $_, $sep;
	$index++;
    }
    
    print "\n";
}

## dl_style ($style, $style_link, $base_dir)
sub dl_style{
    my ($style_name, $style_link, $save_base_dir) = @_;
    my ($statuscode, $headers, $file) = $HTTP->Request($style_link); 


    my $tree = HTML::TreeBuilder->new;
    $tree = $tree->parse_content($file);
	
    my @pres = $tree->find_by_tag_name('p');
    my $desc = "";
    for my $tmp (@pres){
	$desc .= $tmp->as_text() . "\n\n";
    }
    

    mkdir $save_base_dir, 0755 if(!-d $save_base_dir);
    mkdir $save_base_dir . "/" . $style_name, 0755 if(!-d $save_base_dir . "/" . $style_name);
	
    if( ! -f "$save_base_dir/$style_name/$style_name.txt"){
	open (DESC_FILE, ">$save_base_dir/$style_name/$style_name.txt");
	$desc = encode("utf8", $desc);
	print DESC_FILE $desc;
	close(DESC_FILE);
    }

    my @titles = $tree->find_by_attribute('class', 'mTm');
	
#get wall paper list page links.
    my @wplpage_links = (); #wall paper list page links
    my $wplpage_index = 0;
	
    for (@titles && @{$titles[0]->extract_links('a')}) {
	my ($link, $element, $attr, $tag) = @$_;
	$wplpage_links[$wplpage_index] = $link;
	$wplpage_index++;
    }
	
    my @wp_links = (); # wall paper link
    my $wp_index = 0;
	
    if($wplpage_index eq 0){
	# he has only one single page
	$wplpage_links[$wplpage_index++] = $style_link;
	$wplpage_links[$wplpage_index] = "";
    }
    $tree->delete;
    # Get the single wallpaper page links:
    for ($wplpage_index = 0; $wplpage_index < @wplpage_links - 1; $wplpage_index++){
	$tree = HTML::TreeBuilder->new;
	    
	if($wplpage_index eq 0){
	    $tree = $tree->parse_content($file);
	}else{
	    ($statuscode, $headers, $file)=$HTTP->Request($wplpage_links[$wplpage_index]); 
	    $tree = $tree->parse_content($file);
	}
	    
	@titles = $tree->find_by_tag_name('a');
	
	foreach my $title (@titles){
	    for (@{$title->extract_links('a')}) {
		my ($link, $element, $attr, $tag) = @$_;

		if($title->as_text() =~ /$resolution/){

		    $wp_links[$wp_index] = $link;
		    $wp_index++;
		}
	    }
	}
	$tree->delete;
    }

    my @pic_links = (); # wall paper link
    my $pic_index = 0;
    
    for ($wp_index = 0; $wp_index < @wp_links; $wp_index++){
	print STDOUT "\r Getting $wp_links[$wp_index]...";
	($statuscode, $headers, $file) = $HTTP->Request($wp_links[$wp_index]); 
	$tree = HTML::TreeBuilder->new;
	$tree = $tree->parse_content($file);
	@titles = ();
	@titles = $tree->find_by_attribute('class', "wTt wT$resolution_width") or next;
	my ($link, $element, $attr, $tag);
	for ($titles[0] && @{$titles[0]->extract_links('img')}) {
	    ($link, $element, $attr, $tag) = @$_;
	}
	$pic_links[$pic_index++] = $link;
	$tree->delete;
    }
    
    for ($pic_index = 0; $pic_index < @pic_links; $pic_index++){
	my $str = $pic_links[$pic_index];
	$| = 1;
	print STDOUT "\r Getting ", $str, "...";
	
	(my $domain_pic, my $link_pic) = split("//", $str);
	($domain_pic, $link_pic) = split("/", $link_pic);
	
	# download the pic:
	my $INET_pic;
	
	if ($proxy){
	    $INET_pic = new Win32::Internet("Mozilla/3.0", INTERNET_OPEN_TYPE_PROXY, $proxy) or die "Error on Win32::Internet(): $!\n"; 
	}else{
	    $INET_pic = new Win32::Internet(); 
	}
	
	my $HTTP_pic;
	
	my $pic_name = $pic_links[$pic_index];
	$pic_name =~ s/http:\/\/\S*\///;
	
	if(-f "$save_base_dir/$style_name/$pic_name"){
	    # the file already exists.
	    #next;
	}
	
	$INET_pic->HTTP($HTTP_pic, $domain_pic, $user, $pass); 
	($statuscode, $headers, $file)=$HTTP_pic->Request("/".$link_pic); 
	$HTTP_pic->Close();
	
	open(PIC, ">:raw", "$save_base_dir/$style_name/$pic_name") or die "\n[Error] Cannot write to file $!";
	print PIC $file;
	close(PIC);
    }
}


0;
