export PATH=$PATH:/Applications/mCRL2.app/Contents/bin
#mcrl22lps "$1.mcrl2" "$1.lps" -l regular2
#echo "lps generated"
#lps2lts -v -t -D "$1.lps" "$1.lts"
#echo "lts generated"
#lps2pbes -v -c -m -f "$1.mcf" "$1.lps" "$1.pbes"
#echo "pbes generated"
#tracepp /Users/kdmnk/Projects/erlang-with-mcrl2-gen/im/generated/twoPhasedCommitMultiple/mcrl2/specs.lps_dlk_0.trc
#pbes2bool -v "$1.pbes"
#LpsXSim "$1.lps"
#pbessolve -v --file="$1.lts" "$1.pbes"
#ltsgraph "$1.pbes.evidence.lts"
#ltsgraph "$1.lts"



#echo "trace"
#tracepp "$1.lps_act_0_exposeMsgs.trc"
#lps2lts -v -t -D "$1.lps" "$1.lts"
#ltsgraph "$1.lts"

mcrl22lps "$1.mcrl2" "$1.lps" -l regular2
#LpsXSim "$1.lps"
lps2pbes -v -c -f "$1.mcf" "$1.lps" "$1.pbes"
pbessolve -v --file="$1.lps" "$1.pbes"
lps2lts "$1.pbes.evidence.lps" "$1.pbes.evidence.lts"
ltsgraph "$1.pbes.evidence.lts"