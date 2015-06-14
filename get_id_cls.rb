#!ruby -KS
# encoding:CP932
#
# 2015.06.12:KAWAI Toshikazu
# 総合支援センター（キャンパス自立支援室）のノートテイカー割り当てを
# 線形計画法を用いて行う。
# LP_SOLVEの結果から有効な答を取り出す。
# 標準入力または引数のファイルから読んで、標準出力に出す

=begin
  x_id_cls     1
  x_id_cls     0
  の二通りの答えがあるので、答が1のものだけとりだす。
  線形計画法が解けないときに出てくる文字列　This problem is infeasible があったら、答が出せないことを出力する。 
=end

ans = Hash.new {|h, k| h[k] = []}

ARGF.each {|line|
  if /This problem is infeasible/ =~ line
    print line
    exit
  end
  if /x_([\w\d]+)_([\w\d]*)\s+1/ =~ line
    ans[$1] << $2
  end
}
p ans
#縦書き
ans.keys.sort.each {|id|
  ans[id].sort.each {|cls|
    print "#{id},#{cls}\n"
  }
}

#横書き
ans.keys.sort.each {|id|
  print "#{id},#{ans[id].sort.join(',')}\n"
}

