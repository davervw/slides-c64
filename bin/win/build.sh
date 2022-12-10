export ACME=/c/Users/Dave/Downloads/acme0.97win/acme
export VICE=/c/Users/Dave/Downloads/GTK3VICE-3.6.1-win64/bin
${ACME}/acme.exe -f cbm -l build/labels -o build/lores.ml.prg code/lores.asm
[ $? -eq 0 ] || exit 1
[ $? -eq 0 ] && ${VICE}/c1541 << EOF
attach build/slides.d64
delete lores.ml
delete lores.asm
delete license
write build/lores.ml.prg lores.ml
write code/lores.asm lores.asm,s
write LICENSE license,s
EOF
[ $? -eq 0 ] && ${VICE}/x64sc.exe -moncommands build/labels build/slides.d64
