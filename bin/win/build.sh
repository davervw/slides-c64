export ACME=/c/Users/Dave/Downloads/acme0.97win/acme
export VICE=/c/Users/Dave/Downloads/GTK3VICE-3.9-win64/bin
${ACME}/acme.exe -f cbm -l build/lores.labels -r build/lores.lst -o build/lores.ml.prg code/lores.asm 2> build/build.err
result=$?
cat build/build.err
[ ${result} -eq 0 ] || exit 1
rm build/build.err
${ACME}/acme.exe -f cbm -l build/rleplayer.labels -r build/rleplayer.lst -o build/rleplayer.ml.prg code/rleplayer.asm 2> build/build.err
result=$?
cat build/build.err
[ ${result} -eq 0 ] || exit 1
rm build/build.err
${ACME}/acme.exe -f cbm -l build/rleplayer128.labels -r build/rleplayer128.lst -o build/rleplayer128.ml.prg code/rleplayer128.asm 2> build/build.err
result=$?
cat build/build.err
[ ${result} -eq 0 ] || exit 1
rm build/build.err
[ $? -eq 0 ] && ${VICE}/c1541 << EOF
attach build/slides.d64
delete lores.ml
delete lores.asm
delete rleplayer.ml
delete rleplayer128.ml
delete rleplayer.asm
delete rleplayer128.asm
delete license
write build/lores.ml.prg lores.ml
write build/rleplayer.ml.prg rleplayer.ml
write build/rleplayer128.ml.prg rleplayer128.ml
write code/lores.asm lores.asm,s
write code/rleplayer.asm rleplayer.asm,s
write code/rleplayer128.asm rleplayer128.asm,s
write LICENSE license,s
EOF
[ $? -eq 0 ] && ${VICE}/x128.exe -moncommands build/rleplayer128.labels build/slides.d64
