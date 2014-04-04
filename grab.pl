#!d:/perl/bin/perl.exe

use Win32::Internet;        
use HTML::Parser;
use HTML::TreeBuilder;

my $domain = "www.netcarshow.com";
my $INET = new Win32::Internet(); 
$INET->HTTP($HTTP, $domain, "itc\\itc201050", "siGertswIe");


($statuscode, $headers, $file)=$HTTP->Request("/"); 
$HTTP->Close();

#open(OUTFILE, "out.html")||die "cannot create file.";
#print OUTFILE $file;
#close OUTFILE;
print $headers;

my $tree = HTML::TreeBuilder->new;
$tree = $tree->parse_content($file);

#$tree = $tree->parse_file("out.html");

@titles = $tree->find_by_tag_name('li');

my %factories = ();
my @factory_names = ();
my @news = ();
my $index = 0;
my $new_index = 0;

foreach my $title (@titles){
    my $link, $element, $attr, $tag;
    for (@{$title->extract_links('a')}) {
	($link, $element, $attr, $tag) = @$_;
    }

    $factories{$title->as_text()} = $link;
}


my $sep;

sub myfunction
{
    return (shift(@_) cmp shift(@_));
}

$index = 0;

foreach $key (sort {myfunction($a,$b)} keys %factories){
#    print "$key => $factories{$key}\n";
    if($key =~ /\(/){
	@news = (@news, $key);
    }else{
	$factory_names[$index] = $key;
	$index++;
    }

}

sub display_factory
{
    my $index = 0;
    my $sep;
    foreach $name (@factory_names){
	if($index ne 0 && ($index + 1) % 5 eq 0){
	    $sep = "\n";
	}else{
	    $sep = "\t";
	}
	printf "%3d.%13s%s", $index, $name, $sep;
	$index++;
    }

    print "\n\nNew photos:\n";
    foreach $name (@news){
	print $index++, ".", $name, "\n";
    }
    print "\n";
}

display_factory;

my %cnt;
$cnt{"factory"} = @factory_names;
my %prompt;
$prompt{"factory"} = "Please input option(0 - " . ($cnt{"factory"} - 1). "):";

print STDOUT $prompt{"factory"};



while (chop($input = <STDIN>)){
    if (length $input eq 0){
	print $prompt{"factory"};
    }elsif($input eq "q"){
	break;
    }elsif((int $input) >= 0 && (int $input) <= $cnt{"factory"}){
	print $factories{$factory_names[int $input]}, "\n";
    }else{
    }
    print STDOUT $prompt{"factory"};
}

# Now that we're done with it, we must destroy it.
$tree = $tree->delete;


