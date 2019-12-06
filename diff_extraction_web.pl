use Mojolicious::Lite;
use File::Copy;
use open IO => qw/:encoding(UTF-8)/;
binmode STDOUT, ':encoding(UTF-8)';

my $app = app;
my $url = 'http://localhost:3001'; # URL

# トップページ
get '/' => sub {
	my $self = shift;
	$self->render('index', top_page => $url);
};

# データを受け取って処理
post '/' => sub {
	my $self = shift;
	# ホームディレクトリ
	my $home = $app->home;

	# パラメーターの取得
	my $old = $self->param('old');
	my $new = $self->param('new');
	my $nd = $self->param('nd');
	
	# 入力が空の場合はエラー表示
	if (! length $old and ! length $new){
	  $self->render('index', error => 'Old version area and New version area is empty');
	  return;
	} elsif (! length $old){
	  $self->render('index', error => 'Old version area is empty');
	  return;
	} elsif (! length $new){
	  $self->render('index', error => 'New version area is empty');
	  return;
	}

	# tmpフォルダの旧版と新版を削除
	unlink './tmp/old.txt';
	unlink './tmp/new.txt';
	
	# tmpフォルダがなかったら作る
	if ( -d './tmp' ){
	
	} else {
		mkdir 'tmp', 0700 or die "$!";
	}
	
	open( my $old_out, ">:utf8", "tmp/old.txt" ) or die "$!:old.txt";
	open( my $new_out, ">:utf8", "tmp/new.txt" ) or die "$!:new.txt";
	my @old_array = split(/\n/, $old);
	my @new_array = split(/\n/, $new);
	foreach my $line (@old_array){
		print {$old_out} $line . "\n";
	}
	foreach my $line (@new_array){
		print {$new_out} $line . "\n";
	}

	close($old_out);
	close($new_out);
	
	my $tmp_old_fullpath = $home->rel_file('tmp/old.txt');
	my $tmp_new_fullpath = $home->rel_file('tmp/new.txt');

	my @result;
	my $nd_flag = 0;
	my $command;
	if ( defined $nd ){
		# 差異のない箇所のみ抽出
		$command = 'diff.exe -U 1000000 "' . $tmp_old_fullpath . '"' . ' ' . '"' . $tmp_new_fullpath . '"' . ' | grep.exe -E "^ "';
		$nd_flag = 1;
		&Extraction(\@result, $command, $nd_flag);
	} else {
		# newに追加されたテキストのみ抽出
		$command = 'diff.exe "' . $tmp_old_fullpath . '"' . ' ' . '"' . $tmp_new_fullpath . '"' . ' | grep.exe -E "^>"';
		&Extraction(\@result, $command, $nd_flag);
	}
	
	# 差分抽出結果を表示
	$self->render(template => 'result',
				  result => \@result
			     );
};

sub Extraction {
	my ($result, $command, $nd_flag) = @_;
	my $command_result = `$command`;
	my @command_result_array = split(/\n/,$command_result);
	foreach my $line (@command_result_array){
		if ($nd_flag == 1){
			$line =~ s/^ //g; # 行頭の半スペを削除
		} else {
			$line =~ s/^>\s//g; # 行頭の「> 」を削除
		}
		push @$result, $line;
	}
}

app->start;

__DATA__
@@ layouts/common.html.ep
<!doctype html>
<html lang="en">
  <head>
  	<meta charset="utf-8" />
	<script src="https://ajax.googleapis.com/ajax/libs/jquery/3.2.1/jquery.min.js"></script>
	<style type="text/css">
		body {
		    font-family:-apple-system, BlinkMacSystemFont, "Helvetica Neue", "Segoe UI","Noto Sans Japanese","ヒラギノ角ゴ ProN W3", Meiryo, sans-serif;
				width:1250px;
		}
		
		input.upload_button {
		    font-size: 1.0em;
		    font-weight: bold;
		    padding: 8px 20px;
		    background-color: #248;
		    color: #fff;
		    border-style: none;
		}
		
		input.upload_button:hover {
		    background-color: #24d;
		    color: #fff;
		}

		input.clear_button {
		    font-size: 1.0em;
		    font-weight: bold;
		    padding: 8px 20px;
		    background-color: #009250;
		    color: #fff;
		    border-style: none;
		}
		
		input.clear_button:hover {
		    background-color: #3EBA2B;
		    color: #fff;
		}
	</style>
	<link type="text/css" rel="stylesheet" href="http://code.jquery.com/ui/1.10.3/themes/cupertino/jquery-ui.min.css" />
	<script type="text/javascript" src="http://code.jquery.com/jquery-1.10.2.min.js"></script>
	<script type="text/javascript" src="http://code.jquery.com/ui/1.10.3/jquery-ui.min.js"></script>
	
	<title><%= stash('title') %></title>
  </head>
  <body>
    %= content;
  </body>
</html>

@@ index.html.ep
% layout 'common', title => 'Text diff extraction';
%= javascript begin
  // プログレスバー
  $(document).on('click', '#submit', function() {
    $('#progress').progressbar({
        max: 100,
        value: false
		}).height(10);
		// ボタンの非表示
		$('#submit').hide();
		$('#clear').hide();
	});
% end
% my $top_page = stash('top_page');
% my $error = stash('error');
% if ($error) {
  <div style="color:red">
    <%= $error %>
  </div>
% }
<h1>Text diff extraction</h1>
<form action="<%= url_for %>" method="post">
  <%= text_area 'old', style => "width:600px; height:300px", placeholder => "Old version" %> <%= text_area 'new', style => "width:600px; height:300px", placeholder => "New version" %><br>
  </br>
	<span style="font-weight: bold; color:black; border-bottom: solid 1px black;">Option:</span>
  <ul>
  	<li>
  	  <p>Extract text without difference: <%= check_box nd => 1 %></p>
	</li>
  </ul>
  <input class="upload_button" type="submit" id="submit" value="Submit">
	<div id="progress"></div>
</form>
</br>
<input class="clear_button" type="button" id="clear" value="Clear" onClick="location.href='<%= $top_page %>'">
</br>
</br>
<!-- <a href="/static/README.html">README</a> -->

@@ result.html.ep
% layout 'common', title => 'Results';
% for my $line (@$result){ 
<%= $line %></br>
% }
