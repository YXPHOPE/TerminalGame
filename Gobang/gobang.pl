#五子棋
use strict;
use warnings;
use utf8;
eval('use open":encoding(gbk)",":std";') if $^O eq 'MSWin32';
use Encode;
use Term::ANSIColor;
use Term::ANSIColor qw(:constants);
use Carp qw(cluck);
$Term::ANSIColor::AUTORESET = 1;

# use feature 'switch';
# no warnings "experimental::smartmatch";
our ( $USER, $GRDIR, $UDIR ) = ( getlogin || getpwuid($<),, );
our %STYLE = (
    'b',   'bold',      'i', 'italic',
    'u',   'underline', 'c', 'cyan',
    'l',   'blue',      'h', 'black',
    'y',   'yellow',    'g', 'green',
    'r',   'red',       'm', 'magenta',
    'w',   'white',    ##S以上为文字属性、颜色，以下为背景颜色E##
    'bb',  'bright_black',    'br',  'bright_red',
    'bg',  'bright_green',    'by',  'bright_yellow',
    'bl',  'bright_blue',     'bm',  'bright_magenta',
    'bc',  'bright_cyan',     'bw',  'bright_white',
    'ob',  'on_black',        'or',  'on_red',
    'og',  'on_green',        'oy',  'on_yellow',
    'ol',  'on_blue',         'om',  'on_magenta',
    'oc',  'on_cyan',         'ow',  'on_white',
    'obb', 'on_bright_black', 'obr', 'on_bright_red',
    'obg', 'on_bright_green', 'oby', 'on_bright_yellow',
    'obl', 'on_bright_blue',  'obm', 'on_bright_magenta',
    'obc', 'on_bright_cyan',  'obw', 'on_bright_white',
);    ##S颜色属性的简写，用于&prtfmt E##
if ( $^O eq 'linux' ) {
    my ( $name, $passwd, $gid, $members ) = getgrent;
    $GRDIR = "/home/$name/";
}
else {
    $USER  = getlogin || getpwuid($<);
    $GRDIR = "C:/Users/";
}
$UDIR = "$GRDIR$USER/";
our @DIR = (
    "./",   "./mychess/", $UDIR, $UDIR . "mychess/",
    $GRDIR, $GRDIR . "mychess/"
);
our @MODE = ( 'man', 'man', 'play', 'init' )
  ; #先手0,后手1,游戏方式(play, review, onlook),游戏进程(init(未落子),ongoing(联网正在进行),over0/1(已结束),save(已存档(未结束)),auto(自动保存未结束))
our @SYMBOL = ( [ 'o', 'y' ], [ 'o', 'c' ] );
our @STEP   = ();
our @TMP;
our @TMPSTEP = ( [], [] );
our $SIZE    = 15;           # 索引值，实际大小16x16
our @CHESS   = ();           # 使用1和2表示两个玩家的棋子
our %HELP    = (
    'break' => ( "=" x 90 ) . "\n",
    1,
"(同一台设备输入),请输入棋盘大小(输入0或者1则使用默认值, Enter则退出)\n(后可跟样式: 16,o,y,o,l 表示建立 16x16 的棋盘, 用户1使用yellow的o字符代表棋子,用户2使用blue的o字符代表棋子)"
);
our @ALPHA = ( 'a' .. 'z' );
our ( $CONFIRM, $DIFFICULTY, $FILENAME ) = ( 0, 2, );

# PROCESS: init(未落子),ongoing(联网正在进行),over0/1(已结束),save(已存档(未结束)),auto(自动保存未结束)
our $DEBUG = 1;
our @DIRECTION =
  ( [ 0, -5, 0, 1 ], [ -5, 0, 1, 0 ], [ -5, -5, 1, 1 ], [ 5, -5, -1, 1 ] );

sub init {

    # 判断上一局是否正常退出
    mkdir("mychess");
    my @chessdir = glob("./mychess/*");
    @chessdir = reverse sort @chessdir;
    my $last;
    foreach (@chessdir) {
        if (/\d{14}_autosave\.chs/) {
            $last = $_;
            last;
        }
    }
    if ( defined $last ) {
        print CYAN "你的上一局对战($last)尚未结束，是否要加载该次对局？（y|n）\n";
        chomp( my $ysn = lc(<>) );
        if ( $ysn eq 'y' ) {
            history($last);
            last;
        }
    }
    while (1) {
        print YELLOW
          "请选择游戏模式：\n1.人机对战\n2.两人同机\n3.联网对战\n4.打谱练习\n5.历史对战\nEnter.退出\n";
        my $input = substr( <>, 0, -1 );
        $input = quit() if $input eq "";
        last if $input eq ">exit";
        if ( $input =~ /^[1-5]$/ ) {
            $_ = $input;
            if    (/1/) { inputmode( 'man', 'ai' ); }
            elsif (/2/) { inputmode( 'man', 'man' ); }
            elsif (/3/) { &network_chess; }
            elsif (/4/) { &exercise; }
            elsif (/5/) { &history; }
        }
        else { print RED "给我认真点！\n"; }
    }
}
init();

sub save {
    my ( $mode, $file ) = @_;
    $file = $FILENAME if !defined $file;

    # print "file=$file\n";
    if ($mode) {
        open( DATA, "+>", $file );
        print DATA tocode($mode);
        close DATA;
    }
    else {
        print GREEN "是否保存本次战局为文件?(filename/no)\n";
        my $ysn = substr( <>, 0, -1 );
        if ( $ysn eq 'no' || $ysn eq "" ) {
        }
        else {
            $ysn =~ s/[\?\@#\$\&\(\)\\\/\|;'"<>]//g;
            $ysn .= ".chs" if index( $ysn, "." ) == -1;
            open( DATA, "+>", $ysn );
            print DATA tocode("save");
            close DATA;
        }
    }
}

sub tocode {
    $MODE[3] = $_[0] if defined $_[0];
    my $out =
        "\@MODE=\@{"
      . prtcode( \@MODE )
      . "};\@SYMBOL=\@{"
      . prtcode( \@SYMBOL )
      . "};\@STEP=\@{"
      . prtcode( \@STEP )
      . "};\$SIZE="
      . prtcode($SIZE)
      . ";\@CHESS=\@{"
      . prtcode( \@CHESS ) . "};";
    $out;
}

sub prtcode {
    my ( $r, $out ) = ( ref $_[0], "" );
    if ( $r eq '' && defined $_[0] ) {
        $out = $_[0] =~ /^-?\d+(\.\d+)?$/ ? $_[0] : "'$_[0]'";
    }
    elsif ( $r eq 'ARRAY' ) {
        my @arr = @{ $_[0] };
        foreach my $i (@arr) {
            $out .= ( prtcode($i) . "," );
        }
        $out = "[" . substr( $out, 0, -1 ) . "]";
    }
    elsif ( $r eq "HASH" ) {
        my %hash = %{ $_[0] };
        foreach ( sort keys %hash ) {
            $out .= ( "'$_'," . prtcode( $hash{$_} ) . "," );
        }
        $out = "{" . substr( $out, 0, -1 ) . "}";
    }
    else {
        $out = "''";
    }
    $out;
}

# 写入信息
sub mkchess {
    my ( $n, $symbol1, $style1, $symbol2, $style2, @mode ) = @_;
    ( $symbol1, $symbol2 ) =
      map { $_ = 'o' if !defined $_; $_; } ( $symbol1, $symbol2 );
    $style1 = 'y' if !defined $style1 || $style2 eq '';
    $style2 = 'c' if !defined $style2 || $style2 eq '';
    @MODE[ 0, 1 ] = ( @mode[ 0, 1 ], 'play', 'init' );
    @SYMBOL = ( [ $symbol1, $style1 ], [ $symbol2, $style2 ] );
    $SIZE   = $n - 1;
    @STEP   = ( [], [] );
    @CHESS  = map {
        my @row = map { $_ = ' '; } 0 .. $SIZE;
        \@row;
    } 0 .. $SIZE;
    save("auto");
}

sub inputmode {
    my @option = @_;
    @option > 1 ? print GREEN "人机对战\n" : print GREEN "两人同机对战\n";
    my $input = substr( <>, 0, -1 );
    $FILENAME = "./mychess/" . gettime() . "_autosave.chs";
    while (1) {
        $input = quit() if $input eq "";
        last            if $input eq ">exit";
        $input =~ s/ +/,/g;
        $input = tohalfangle($input);
        $input = validate( $input, @option );
        last if $input eq ">exit" || $input eq 'won';
    }
    save() if ( @{ $STEP[0] } > 3 );
}

#检验输入的合法性，合法则直接开始游戏，不合法则重新输入并返回输入的值
sub validate {
    my ( $input, @mode ) = @_;
    my @option = split( ',', $input );
    $option[4] = '' if !defined $option[4];
    push @option, @mode;
    my ( $flag, $n ) = ( 0, $option[0] );
    if ( $input eq '0' || $input eq '1' ) {
        $flag = 1;
        $option[0] = 16;
    }
    elsif ( $input =~ /^\d+(,.,[a-z&]+){0,2}/ ) {
        if    ( $n > 4 && $n < 27 ) { $flag = 1 }
        elsif ( $n < 5 ) { print RED "你在想嘛呢, 这棋盘给谁下! 你想下 $n 子棋吗?\n"; }
        elsif ( $n > 26 ) {
            print RED "棋盘太恐怖了, 臣妾就算算得起, 也显示不起啊(害,主要是横轴的英文字母只有26个)\n";
        }
    }
    else { print RED "眼睛睁大看仔细点\n"; }
    if ( $flag == 1 ) {
        mkchess(@option);
        my $res = runchess();
        return $res;
    }
    else { $input = substr( <>, 0, -1 ); $input; }
}

sub runchess {
    show();
    my $res;
    while (1) {
        my @steps0 = @{ $STEP[0] };
        my @steps1 = @{ $STEP[1] };
        return ">over" if ( @steps0 + @steps1 ) == $SIZE * $SIZE;
        print "steps0="
          . ( $#steps0 + 1 )
          . "   steps1="
          . ( $#steps1 + 1 ) . "\n"
          if $DEBUG;
        my $n = $#steps0 > $#steps1 ? 1 : 0;
        my $m = $n                  ? 0 : 1;
        print "现在指定 $n 下子\n";
        $res = falllocation($n);
        my @stepsm = @{ $STEP[$m] };

        if ( $res eq ">back" && @stepsm > 0 ) {

            if ( $MODE[0] eq 'ai' || $MODE[1] eq 'ai' ) {
                my @remove  = @{ $steps0[$#steps0] };
                my @remove2 = @{ $steps1[$#steps1] };
                $CHESS[ $remove[0] ]->[ $remove[1] ]   = ' ';
                $CHESS[ $remove2[0] ]->[ $remove2[1] ] = ' ';
                pop @{ $STEP[1] };
                pop @{ $STEP[0] };
            }
            else {
                my @remove = @{ $stepsm[$#stepsm] };
                $CHESS[ $remove[0] ]->[ $remove[1] ] = ' ';
                pop @{ $STEP[$m] };
                my @stepn = @{ $STEP[$n] };
            }
            if ( @steps0 > @steps1 ) {
                my @loc = @{ $steps0[$#steps0] };
                show( @loc, 'ow' );
            }
            else {
                my @loc = @{ $steps1[$#steps1] };
                show( @loc, 'ow' );
            }

            # print "rem=@remove\n";
            # print "loc=@loc\n";
        }
        my @judge = judge($n) if $res eq ">done";
        print "step0=" . ( $#steps0 + 1 ) . "\n" if $DEBUG;
        if ( $judge[0] ) {
            my $won = $judge[1];
            prtfmt( "{b&$SYMBOL[$won]->[1]}|+| $SYMBOL[$won]->[0] |+|获得胜利! \n",
                'l' );
            $MODE[3] = "over$won";
            save("over$won");
            return "won";
        }
        return '>exit' if $res eq ">exit";
    }
}

sub falllocation {
    my $n = $_[0];    # n为0或1, 指两个玩家
    my ( $input, @res, @rc );
    if ( $MODE[$n] eq 'man' ) {
        while (1) {
            prtfmt(
                "请 |+|{b&$SYMBOL[$n][1]}$SYMBOL[$n][0]|+| 下第 "
                  . ( @{ $STEP[$n] } + 1 ) . " 个子\n",
                'g'
            ) if !$res[0];
            $input = substr( <>, 0, -1 ) if !$res[0];
            $input = $res[1]             if $res[1];
            $input = quit()              if $input eq "";
            return ">exit" if $input eq ">exit";
            return ">back" if $input eq "back";
            if ( $input eq 'cue' ) {
                @rc  = ai($n);
                @res = fall( @rc, $n );
                $res[0] ? next : last;
            }
            $input = dsphelp('fall') if $input eq "help";
            $input = lc($input);
            $input =~ s/([^ ]) +([^ ])/$1,$2/g;
            $input =~ s/ +//g;
            @rc = ( $input, $input );
            $rc[0] =~ s/[^\d]//g;     # 剩余数字，为y轴
            $rc[0] = 0 if $rc[0] eq "";
            $rc[1] =~ s/[^a-z]//g;    # 剩余字母，为x轴
            $rc[1] = indexof( $rc[1], \@ALPHA ) + 1;

            if ( $input =~ /^\d+,\d+$/ ) {
                @rc = reverse split( ',', $input );    # 输入两个数字：前者为横轴，后者为竖轴
            }
            elsif ( $input =~ /^\d+$/ ) {
                @rc = reverse split( '', $input ) if length($input) == 2;
                @rc = ( substr( $input, 2 ), substr( $input, 0, 2 ) )
                  if length($input) == 4;
            }
            elsif ( $input =~ /^[a-z]{2}$/ ) {
                @rc = reverse split( '', $input );
                @rc = map { $_ = indexof( $_, \@ALPHA ) + 1; } @rc;
            }

            # print "rc0=@rc\n" if $DEBUG;
            @rc = map { $_ = $_ - 1; } @rc;

            # print "rc1=@rc\n" if $DEBUG;
            if (   $rc[0] > -1
                && $rc[0] <= $SIZE
                && $rc[1] > -1
                && $rc[1] <= $SIZE )
            {
                @res = fall( @rc, $n );
                $res[0] ? next : last;
            }
            else {
                print RED "哎呀, 棋子落到棋盘外去啦! \n";
                @res = ( 0, 0 );
                next;
            }
        }
    }
    elsif ( $MODE[$n] eq "ai" ) {
        @rc = aix($n);    # 由ai给出对yu$n最佳位点 @{ $STEP[0] } < 3 ? ai($n) :
        print YELLOW BOLD "rc=@rc\n" if $DEBUG;
        $CHESS[ $rc[0] ]->[ $rc[1] ] = $n;
    }

    push @{ $STEP[$n] }, \@rc;
    getpoint($n);

    # 棋盘发生变化，此处应当保存
    save("auto") if @{ $STEP[0] } > 4;
    show( @rc, 'ow' );
    if ( $MODE[0] eq 'ai' && $MODE[1] eq 'ai' ) { my $c = <>; }
    return ">done";
}

sub prtmatrix {    ##SprintmatrixE##
    my @arr = @{ $_[0] };
    my $out = "[[\t";
    if ( ref $arr[0] ) {
        foreach my $i ( 0 .. $#arr ) {
            my @tmp = @{ $arr[$i] };
            foreach my $j (@tmp) {
                $out .= "$j\t";

            }
            $out = substr( $out, 0, -1 ) . "\t]\n [\t";
        }
        $out = substr( $out, 0, -4 ) . "]\n";
        print CYAN"$out";
    }
    else { print CYAN"[ @arr ]\n"; }
}

sub aix {
    our $i = $_[0];
    our $e = $i ? 0 : 1;
    @TMPSTEP = map { my $g = $_; $g; } @STEP;
    our @range;
    my @dir = (
        [ 0,  -1 ], [ 0,  1 ],  [ 1,  -1 ], [ 1,  0 ],
        [ 1,  1 ],  [ -1, -1 ], [ -1, 0 ],  [ -1, 1 ],
        [ 0,  -2 ], [ 0,  2 ],  [ 1,  -2 ], [ 1,  2 ],
        [ -1, -2 ], [ -1, 2 ],  [ -2, -2 ], [ -2, -1 ],
        [ -2, 0 ],  [ -2, 1 ],  [ -2, 2 ],  [ 2,  -2 ],
        [ 2,  -1 ], [ 2,  0 ],  [ 2,  1 ],  [ 2,  2 ],
    );
    foreach my $st ( @{ $STEP[0] }, @{ $STEP[1] } ) {   # 由原先的从棋盘判断后获取，变为直接从步数获取
        my ( $r, $c ) = ( $st->[0], $st->[1] );
        foreach (@dir) {                                # 8+16
            my ( $x, $y ) =
              ( $r + $_->[0], $c + $_->[1] );
            my $n = $CHESS[$x]->[$y] if $x > -1 && $y > -1;
            if ( defined $n && $n eq ' ' ) {
                push @range, [ $x, $y ]
                  if indexofarr( [ $x, $y ], \@range, 1 ) == -1;

                # print "[$x,$y]\n";
                # prtmatrix( \@range );
            }
        }
    }
    our ( $depth, @step ) = ( 0, 0 );
    my $point = search();
    shift @step;
    return @{ $step[0] };

    sub search {
        my ($upper) = ( $_[0] );
        $depth++;
        my $maxmin;

   # DIFFICULTY 为奇数,搜索程度,搜索到我方下子后的棋局分数取最大,传给上一步对方,对方在众多最大值中选最小的,再往上传给己方,己方再选择最大的
        if ( $depth > $DIFFICULTY ) {
            $depth--;
            my $x = getpoint($i);

            # print "终步得分=$x\n";
            return $x;
        }
        else {
            # 遍历该层每一个空位点, 并由相应方下子
            # print "depth= $depth\n";
            foreach my $rc (@range) {

                # print "rc=@{$rc}\n";
                my ( $i, $j ) = ( $rc->[0], $rc->[1] );
                my $x = $CHESS[$i]->[$j];
                if ( $x eq ' ' ) {
                    # print "  "x$depth."$depth:[$i,$j]\n";
                    $CHESS[$i]->[$j] = ( $depth % 2 );
                    my $p = search($maxmin);
                    if ( $depth % 2 == 0 ) {

                        # 偶数敌方层，取min
                        if ( defined $upper && $p < $upper ) {
                            $depth--;
                            $CHESS[$i]->[$j] = ' ';
                            print RED "even jz $p<$upper\n";
                            return $upper;    # 剪枝
                        }
                        if ( !defined $maxmin || $p < $maxmin ) {
                            print CYAN "eve min $maxmin -> $p\n";
                            $maxmin = $p;
                            $step[$depth] = [ $i, $j ];
                        }
                    }
                    else {
                        # 奇数己方层，取max
                        if ( defined $upper && $p > $upper ) {
                            $depth--;
                            $CHESS[$i]->[$j] = ' ';
                            print RED "odd  jz $p>$upper\n";
                            return $upper;    # 剪枝
                        }
                        if ( !defined $maxmin || $p > $maxmin ) {
                            print CYAN "odd max $maxmin -> $p\n";
                            $maxmin = $p;
                            $step[$depth] = [ $i, $j ];
                        }
                    }
                    $CHESS[$i]->[$j] = ' ';
                }
            }

            # 该层遍历完毕
        }
        $depth--;

        print "sco-$depth:$maxmin\n";
        return $maxmin;
    }

}

sub getpoint {
    our $i = $_[0];
    my $e = $i ? 0 : 1;

    # 遍历横行
    our @point = ( 0, 0 );
    foreach my $r ( 0 .. $SIZE ) {

        # print "r=$r\n";
        my ( $row, $pdiag, $mdiag ) = ( '', '', '' );
        $row = join( '', @{ $CHESS[$r] } );

        # print CYAN "row:$row|\n";
        givegrade($row) if $row =~ /[01]/;
        foreach ( numarr( $r, -1 ) ) { $mdiag .= ( $CHESS[$_]->[ $r - $_ ] ); }
        givegrade($mdiag) if $mdiag =~ /[01]/;

        # print CYAN "mdi:$mdiag|\n";
        foreach ( $r .. $SIZE ) { $pdiag .= ( $CHESS[$_]->[ $_ - $r ] ) }
        givegrade($pdiag) if $pdiag =~ /[01]/;

        # print CYAN "pdi:$pdiag|\n";
    }
    my $col = '';
    foreach (@CHESS) { $col .= ( $_->[0] ) if defined $_->[0]; }

    # print "c=0\ncol:$col|\n";
    givegrade( ($col) ) if $col =~ /[01]/;
    foreach my $c ( 1 .. $SIZE ) {

        # print "c=$c\n";
        my ( $col, $pdiag, $mdiag ) = ( '', '', '' );
        foreach (@CHESS) { $col .= ( $_->[$c] ) if defined $_->[$c]; }

        # print "col=$col|\n";
        givegrade( ($col) ) if $col =~ /[01]/;
        foreach ( $c .. $SIZE ) {
            $mdiag .= ( $CHESS[ $SIZE + $c - $_ ]->[$_] );
        }

        # print "mdi=$mdiag|\n";
        givegrade($mdiag) if $mdiag =~ /[01]/;
        foreach ( $c .. $SIZE ) { $pdiag .= ( $CHESS[ $_ - $c ]->[$_] ) }

        # print "pdi=$pdiag|\n";
        givegrade($pdiag) if $pdiag =~ /[01]/;
    }

    sub givegrade {
        return 0 if length( $_[0] ) < 5;
        foreach my $n ( 0 .. 1 ) {
            $_ = $_[0];
            my $m = $n ? 0 : 1;
            if (/$n{5,}/)  { $point[$n] += 100000 }
            if (/ $n{4} /) { $point[$n] += 10000 }
            if ( /^|$m$n{4} / || / $n{4}$m|$/ ) { $point[$n] += 1000 }
            if ( /$n{1,} $n{3,}/ || /$n{2,} $n{2,}/ || /$n{3,} $n{1,}/ ) {
                $point[$n] += 1000;
            }
            if (/ $n{3} /)                      { $point[$n] += 1000 }
            if ( /^|$m$n{3} / || / $n{3}$m|$/ ) { $point[$n] += 500 }
            if ( / $n $n$n / || / $n$n $n / )   { $point[$n] += 500 }
            if (/ $n{2} /)                      { $point[$n] += 50 }
            if ( /$m{1,}$n$m{1,}/)              {$point[$n]+=10}
            if ( /01/ || /10/ )                 { $point[$i] += 1; }
        }
    }
    my $g = $point[$i] - $point[$e];

    # print "对于 $i 一方得分为$g\n" if $DEBUG;
    return $g;
}

sub ai {
    my $n = $_[0];
    my $f = $n ? 0 : 1;
    if ( @{ $STEP[0] } == 0 ) {
        return (
            int( $SIZE / 2 - 1 + rand(2.8) ),
            int( $SIZE / 2 - 1 + rand(2.8) )
        );
    }
    our ( $tmp, @range ) = ( 0, 10, 0, 10, 0 );

    foreach my $step ( @{ $STEP[0] }, @{ $STEP[1] } ) {
        foreach my $rc ( 0 .. 1 ) {
            $tmp                  = $step->[$rc];
            $range[ $rc * 2 ]     = $tmp if $tmp < $range[ $rc * 2 ];
            $range[ $rc * 2 + 1 ] = $tmp if $tmp > $range[ $rc * 2 + 1 ];
        }
    }
    foreach ( 0 .. 1 ) {
        $range[ $_ * 2 ] = $range[ $_ * 2 ] < 2 ? 0 : $range[ $_ * 2 ] - 2;
        $range[ $_ * 2 + 1 ] =
            $range[ $_ * 2 + 1 ] > $SIZE - 2
          ? $SIZE
          : $range[ $_ * 2 + 1 ] + 2;
    }
    print "range=@range\n" if $DEBUG;

    sub drill {
        my $i = $_[0];    #下棋方 步数
        my @expt;
        my $o = $i ? 0 : 1;
        foreach my $r ( $range[0] .. $range[1] ) {
            foreach my $c ( $range[2] .. $range[3] ) {
                my $x = $CHESS[$r]->[$c];
                if ( !defined $x || $x eq ' ' ) {
                    $CHESS[$r]->[$c] = $i;
                    my $g = getgrade( $i, $r, $c );
                    if ( $g == 0 ) {

                        $CHESS[$r]->[$c] = ' ';
                        next;
                    }
                    $CHESS[$r]->[$c] = $o;
                    my $og = getgrade( $o, $r, $c );
                    $CHESS[$r]->[$c] = ' ';
                    push @expt, [ $r, $c, $g + $og * 0.5 ];    # + $og * 0.8
                }
            }
        }
        return @expt;
    }
    my @exp = drill($n);
    foreach (@exp) {
        print "exp=@{$_}\t" if $DEBUG;
    }
    my @best;
    foreach (@exp) {
        push @best, $_ if $_->[2] > 2;
    }
    foreach (@best) {
        print "我方第一步最好的里面的某个= @{$_} 我方下在这里后长这样:\n" if $DEBUG;
        my @rc = @{$_};
        $CHESS[ $rc[0] ]->[ $rc[1] ] = $n;
        show() if $DEBUG;
        my @rcg = drill($f);
        my @gra = map { my $g = $_->[2]; $g; } @rcg;

        my $sel = indexof( max(@gra), \@gra );
        my ( $r, $c ) = ( $rcg[$sel]->[0], $rcg[$sel]->[1] );
        if ( $rcg[$sel]->[2] > 3000 ) {
            if   ( $rcg[$sel]->[2] > 6000 ) { $_->[2] -= 8000; }
            else                            { $_->[2] -= 3000; }
            $CHESS[ $rc[0] ]->[ $rc[1] ] = " ";
            next;
        }
        $_->[2] -= $rcg[$sel]->[2] * 0.8;
        print "此时敌方最佳位点 $r,$c,$rcg[$sel]->[2],此子得分 $_->[2]  落子后:\n" if $DEBUG;
        $CHESS[$r]->[$c] = $f;
        show() if $DEBUG;
        @rcg             = ();
        @rcg             = drill($n);
        $CHESS[$r]->[$c] = " ";
        @gra             = map { my $g = $_->[2]; $g; } @rcg;
        my $m = max(@gra);
        $_->[2] += $m * 0.2;
        print "此时我方最佳位点 "
          . join( ",", @{ $rcg[ indexof( $m, \@gra ) ] } )
          . ",此子得分 $_->[2]\n"
          if $DEBUG;
        $CHESS[ $rc[0] ]->[ $rc[1] ] = " ";
    }
    @best = @exp if @best == 0;
    my @grade = map { my $g = $_->[2]; $g; } @best;
    foreach (@best) {
        print "best=@{$_}\t" if $DEBUG;
    }
    my @sel = indexof( max(@grade), \@grade, 0, 'all' );
    print "\n此时我方最佳位点 为" . join( "  ", @{ $best[ $sel[0] ] } ) . "\n" if $DEBUG;

    # while (1){
    #     $s= indexof($m,\@grade,$s+1);
    #     last if $s ==-1;
    #     print "num $s= @{$exp[$s]}\n" if $DEBUG;
    #     push @sel,$s;
    # }

    # print "exp=@exp\n" if $DEBUG;
    my @rc = @{ $best[ $sel[ int( rand( $#sel + 1 ) ) ] ] };

    # print "rc=@rc\n" if $DEBUG;
    pop @rc;
    return @rc;
}

sub indexofarr {
    my @a = @{ $_[0] };
    my @o = @{ $_[1] };
    my @res;
    foreach ( 0 .. $#o ) {

        # cluck RED "0?";
        my @c = @{ $o[$_] };
        next if $#c != $#a;
        my $flag = 1;
        foreach ( 0 .. $#c ) {
            if ( $c[$_] ne $a[$_] ) {
                $flag = 0;
                last;
            }
        }
        return $_ if $flag && $_[2];
        push @res, $_ if $flag;
    }
    return -1    if $_[2];
    $res[0] = -1 if !defined $res[0];
    @res;
}

sub loadfile {
    open( DATA, "<", $_[0] ) || do { cluck $!; return ">error: $!"; };
    $FILENAME = $_[0];
    my $str = <DATA>;    # !只运行第一行!!
    eval($str) || do { print RED "文件载入失败!\n"; close DATA; return ">exit"; };
    close DATA;
    if ( $MODE[3] =~ /over/ ) {
        print YELLOW "此战局已结束,您要观棋(l)还是退出(其他默认退出)?";
        my $input = lc substr( <>, 0, -1 );
        if ( $input eq 'l' ) {
            $FILENAME = "./mychess/" . gettime() . "_autosave.chs";
            $MODE[2] = "onlook";
        }
        else {
            return ">exit";
        }
    }
}

sub dsphelp {    ##S display help E##
    prtfmt( $HELP{ $_[0] }, 'g' );
    print CYAN $HELP{"break"};
    print YELLOW "请输入: \n";
    substr( <>, 0, -1 );
}

sub fall {
    my ( $row, $col, $n ) = @_;
    my $target = $CHESS[$row]->[$col];
    if ( $target eq ' ' ) {
        $CHESS[$row]->[$col] = $n;

        # print "rc2=$row $col\n";
        if ($CONFIRM) {
            show( $row, $col, 'ow' );
            print CYAN "即将落子在加粗处, Enter确认, 再次输入坐标以重新选择(输入m关闭此提醒)\n";
            my $input = substr( <>, 0, -1 );
            if ( $input eq '' ) {
                return ( 0, 0 );
            }
            elsif ( $input eq 'm' ) {
                print YELLOW "已关闭确认提醒\n";
                $CONFIRM = 0;
            }
            else {
                $CHESS[$row]->[$col] = ' ';
                return ( 1, $input );
            }
        }
    }
    else {
        print RED "该处已有棋子了, 你想干啥子? \n";
        my $input = substr( <>, 0, -1 );
        return ( 1, $input );
    }
    return ( 0, 0 );
}

sub network_chess {
    print "暂未开放,敬请期待.\n";
}

sub exercise {
    print "暂未开放,敬请期待.\n";
}

sub getgrade {
    my ( $n, @rc ) = @_;
    my @line  = get4line( \@rc, $n, [ ' ', 1, 0, 2 ] );
    my $grade = 0;
    foreach (@line) {
        if    (/[12]{5,}/)  { $grade += 100000 }
        elsif (/ [12]{4} /) { $grade += 10000 }
        elsif (/ [12]{3} /) { $grade += 1000 }
        elsif (/ 11 2 /
            || / 1 12 /
            || / 12 1 /
            || / 1 21 /
            || / 21 1 /
            || / 2 11 / )
        {
            $grade += 1000;
        }
        elsif ( / 12 / || / 21 / )   { $grade += 50 }
        elsif ( / 1 2 / || / 2 1 / ) { $grade += 20 }
        elsif ( /02/ || /20/ )       { $grade += 1 }
    }
    $grade;
}

sub get4line {
    my @rc = @{ $_[0] };    # 0.\@loc 2.$n0/1  3.\@sty(空子,我方,敌方,下子处);
    my ( $n, @sty ) = ( $_[1], @{ $_[2] } );
    @sty = ( ' ', '1', '0', '2' ) if @sty < 4;
    my ( $line, $x, @res, @rcx );
    foreach my $dir (@DIRECTION) {
        my @point = ( $rc[0] + $dir->[0], $rc[1] + $dir->[1] );

        # print "point=@point\n";
        my @drc = ( $dir->[2], $dir->[3] );

        # print "drc=@drc\n";
        foreach my $i ( 1 .. 10 ) {
            @rcx = map { $point[$_] + $i * $drc[$_] } 0 .. 1;
            next if $rcx[0] < 0 || $rcx[1] < 0;
            $x = $CHESS[ $rcx[0] ]->[ $rcx[1] ];

            # print "$rcx[0].$rcx[1]=$x\n" if $x;
            if    ( !defined $x || $x eq ' ' ) { $line .= $sty[0] }
            elsif ( $x eq $n ) {
                if ( $rc[0] == $rcx[0] && $rc[1] == $rcx[1] ) {
                    $line .= $sty[3];
                }
                else { $line .= $sty[1] }
            }
            else { $line .= $sty[2] }
        }
        push @res, $line;
        $line = '';
    }
    @res;
}

sub history {
    my $res;
    if ( defined $_[0] ) {
        loadfile( $_[0] );
        $res = runchess();
    }
    else {
        my @filelist = ( 0, );
        my ( $n, $input ) = ( 0, );
        print YELLOW "请选择你要打开的文件(Enter退出):\n";
        foreach (@DIR) {
            my ( @tmp, @file ) = ( glob("$_*"), );

            # print "@tmp";
            foreach (@tmp) {
                push @file, $_ if $_ =~ /\.chs$/;
            }
            push @filelist, @file;
            print GREEN BOLD "$_\n" if @file > 0;
            foreach my $i (@file) {
                $n++;
                $i = Encode::decode( "gb2312", $i );
                my $out = "  $n. $i\n";
                $out =~ s/$_//;
                print CYAN $out;
            }
        }
        while (1) {
            $input = substr( <>, 0, -1 );
            $input = quit() if $input eq "";
            return ">exit"              if $input eq ">exit";
            $input = dsphelp('history') if $input eq "help";
            if ( $input =~ /^\d+$/ ) {
                if ( $input > 0 && $input <= $n ) {
                    $res = loadfile( $filelist[$input] );
                    if ( $res eq ">exit" ) { print YELLOW "请重新选择文件\n"; next; }
                    $res = runchess();
                    last;
                }
                else { print RED "超限了哟!哪有这个数字?\n" }
            }
            else { print RED "输入开头的数字就好了呢!\n" }
        }
    }
}

sub show {
    my @rc = map { $_ = defined $_[$_] ? $_[$_] : ''; } 0 .. 2;

    if    ( $^O eq 'linux' && !$DEBUG )   { system('clear'); }
    elsif ( $^O eq 'MSWin32' && !$DEBUG ) { system("cls"); }
    my @alpha = map { $_ = $ALPHA[$_]; } 0 .. $SIZE;
    my $xaxis = "   |+|{l&b}" . join( " ", @alpha ) . "|+|\n";
    my $out   = $xaxis;

    foreach my $r ( 0 .. $SIZE ) {
        my $num = $r + 1 < 10 ? " " : "";
        $num .= ( $r + 1 );
        $out .= "|+|{l&b}$num|+| ";
        foreach my $c ( 0 .. $SIZE ) {
            my $n = $CHESS[$r]->[$c];
            if ( $r eq $rc[0] && $c eq $rc[1] && $n ne ' ' ) {
                $out .= "|+|{$rc[2]&$SYMBOL[$n][1]}$SYMBOL[$n][0]|+| ";
            }
            elsif ( $n ne ' ' ) {
                $out .= "|+|{$SYMBOL[$n][1]}$SYMBOL[$n][0]|+| ";
            }
            else { $out .= "+ "; }
        }
        $out .= "|+|{l&b}" . ( $r + 1 ) . "|+|\n";
    }
    $out .= $xaxis;
    prtfmt($out);
}

sub sort {    ##S数字大小和其他字符的ASCII代码大小 E##
    if ( $a =~ /^-?[0-9\.]+$/ && $b =~ /^-?[0-9\.]+$/ ) { $a <=> $b }
    else                                                { $a cmp $b; }
}

sub tohalfangle {    ##S全角字符转为半角字符E##
    my %a = qw/！ ! ￥ $ （ ( ） ) — - 【 [ 】 ] 、 \  。 . ； ; ： : ‘ ' “ " ’ ' ” "/;
    @_ = map {
        my $s = $_;
        map { $s =~ s/$_/$a{$_}/g; } keys(%a);
        $s =~ s/，/,/g;
        $s
    } @_;
    @_ == 1 ? $_[0] : @_;
}

sub judge {
    my $i    = shift;
    my @step = @{ $STEP[$i] };
    if ( @step > 4 ) {
        my @last = @{ $step[$#step] };
        my @line = get4line( \@last, $i, [ ' ', 1, 0, 1 ] );
        foreach (@line) {
            if (/1{5,}/) { return ( 1, $i ); }
        }
    }
    return ( 0, 0 );
}

sub max {
    my @arr = sort { $a <=> $b } (@_);
    $arr[$#arr];
}

sub min {
    my @arr = sort { $a <=> $b } (@_);
    $arr[0];
}

sub gettime {
    my ( $mode, $str ) = shift;
    my @t = localtime(time);
    $t[4] += 1;
    $t[5] += 1900;
    @t = map { sprintf "%02s", $_ } @t;    ##S sprintf 格式化输出%代表第一个变量，s开头补0至2位E##
    my ( $s, $m, $h, $day, $mon, $year, $wday, $yday, $isdst ) = @t;
    if   ($mode) { eval( '$str="' . $mode . '";' ); }
    else         { $str = "$t[5]$t[4]$t[3]$t[2]$t[1]$t[0]"; }
    $str;
}

sub quit {
    print YELLOW "再次Enter确认退出或重新输入上一个参数:  ";
    my $ysn = substr( <>, 0, -1 );
    $ysn eq ""
      ? return ">exit"
      : return $ysn;
}

sub prtfmt
{ ##S printformatted格式化输出,prtfmt("|+|{样式}内容|+|","全局样式",可选"正则表达式 样式"), 注意正则表达式将会截断原来的分隔。例如：prtfmt("{b&y}|+|head|+|{c&ol}middle|+|footer\n",'g','e r');E##
    my ( $str, $presty ) = @_;
    foreach my $i ( 2 .. $#_ ) {
        my @ss = split( ' ', $_[$i] );
        $str =~ s/($ss[0])/|+|{$ss[1]}$1|+|/g;
    }
    if ( $str !~ /\|\+\|\{/ && !$presty ) {
        print "$str";
        return 1;
    }
    $str =~ s/(\|\+\|\{[^\}]+\})/$1\|\+\|/g;
    my @arr = split( /\|\+\|/, $str );
    my $n   = 0;
    while ( $n < @arr ) {
        my ( $x, $stystr, $flag ) = ( $arr[$n], '', 1 );
        $stystr = $presty . '&' if $presty;
        if ( $x =~ /^\{[a-z\&]+\}$/ ) {
            $stystr .= $x;
            $stystr =~ s/\{|\}//g;
            $flag = 2;
        }
        my $out = $arr[ $n + $flag - 1 ];
        if ( $stystr ne '' ) {
            my @styarr = split( '&', $stystr );
            my @sty    = map {
                next if $_ =~ /^ *$/;
                my $s = $STYLE{$_};
                $s if $s;
            } @styarr;
            print colored( [@sty], $out );
        }
        else { print $out; }
        $n += $flag;
    }
}

sub indexof {    ##S数组、字符串索引，注意无法区分数字和带引号的数字,query,@/$,[offset,]match,allE##
    my $q = $_[0];
    my @a = ref( $_[1] ) eq "ARRAY" ? @{ $_[1] } : split( "", $_[1] );
    $_[2] = '' if !defined $_[2];
    $_[3] = '' if !defined $_[3];
    my $s   = ( $_[2] =~ /^-?[1-9][0-9]*$/ ) ? $_[2] : 0;
    my @arr = $s >= 0 ? ( $s .. $#a ) : numarr( $#a + $s + 1, -1 );
    my @res;
    foreach my $i (@arr) {
        if ( $_[2] eq "false" || $_[3] eq "false" ) {
            if ( $_[3] eq 'all' || ( defined $_[4] && $_[4] eq 'all' ) ) {
                push @res, $i if ( $a[$i] =~ /$q/ );
            }
            else { return $i if ( $a[$i] =~ /$q/ ); }
        }
        else {
            if ( $_[3] eq 'all' || ( defined $_[4] && $_[4] eq 'all' ) ) {
                push @res, $i if ( $q eq $a[$i] );
            }
            else { return $i if ( $q eq $a[$i] ); }
        }
    }
    $res[0] = -1 if !defined $res[0];
    return @res;
}

sub numarr {    ##E生成数组E##
    my ( $s, $e, $m ) = @_;
    if ( !$m ) {
        $m = $e > $s ? 1 : -1;
    }
    my @arr = ();
    my $n   = abs( ( $e - $s ) / $m );
    foreach my $i ( 0 .. $n - 1 ) {
        $arr[$i] = $s + $i * $m;
    }
    @arr;
}
