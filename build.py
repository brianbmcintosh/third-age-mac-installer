#!/usr/bin/env python3
"""Build a self-contained universal Mac app using Apple's Command Line Tools."""
from pathlib import Path
import argparse, os, plistlib, shutil, subprocess

root=Path(__file__).resolve().parent
parser=argparse.ArgumentParser()
parser.add_argument('--out',type=Path,default=root/'.build')
parser.add_argument('--arch',choices=['arm64','x86_64','universal'],default='universal')
parser.add_argument('--identity',help='Optional Developer ID Application signing identity')
args=parser.parse_args()
out=args.out.resolve();out.mkdir(parents=True,exist_ok=True)
sdk=subprocess.check_output(['xcrun','--sdk','macosx','--show-sdk-path'],text=True).strip()
env=dict(os.environ,CLANG_MODULE_CACHE_PATH=str(out/'module-cache'))
architectures=['arm64','x86_64'] if args.arch=='universal' else [args.arch]
for arch in architectures:
    target=f'{arch}-apple-macosx12.0'
    obj=out/f'ArchiveIO-{arch}.o'
    subprocess.run(['xcrun','clang','-target',target,'-isysroot',sdk,'-O2','-Wall','-Wextra','-c',str(root/'Sources/ArchiveIO.c'),'-o',str(obj)],check=True,env=env)
    subprocess.run(['xcrun','swiftc','-swift-version','5','-target',target,'-sdk',sdk,'-O','-module-cache-path',str(out/'module-cache'),'-import-objc-header',str(root/'Sources/ArchiveIO.h'),str(root/'Sources/Core.swift'),str(root/'Sources/App.swift'),str(obj),'-lz','-lbz2','-framework','AppKit','-framework','CryptoKit','-o',str(out/f'ThirdAge-{arch}')],check=True,env=env)

app=out/'Third Age for Mac.app'
if app.exists():shutil.rmtree(app)
contents=app/'Contents';(contents/'MacOS').mkdir(parents=True);(contents/'Resources').mkdir()
binary=contents/'MacOS/ThirdAge'
if len(architectures)>1:
    subprocess.run(['lipo','-create',*[str(out/f'ThirdAge-{arch}') for arch in architectures],'-output',str(binary)],check=True)
else:shutil.copy2(out/f'ThirdAge-{architectures[0]}',binary)
info={'CFBundleName':'Third Age for Mac','CFBundleDisplayName':'Third Age for Mac',
      'CFBundleIdentifier':'community.thirdage.macinstaller','CFBundleExecutable':'ThirdAge',
      'CFBundlePackageType':'APPL','CFBundleShortVersionString':'0.1.0','CFBundleVersion':'1',
      'LSMinimumSystemVersion':'12.0','NSHighResolutionCapable':True,
      'NSHumanReadableCopyright':'Unofficial community installation helper. Third Age belongs to its creators.'}
icon=root/'Resources/AppIcon.icns'
if icon.exists():shutil.copyfile(icon,contents/'Resources/AppIcon.icns');info['CFBundleIconFile']='AppIcon.icns'
(contents/'Info.plist').write_bytes(plistlib.dumps(info))
for name in ['LICENSE','THIRD_PARTY_NOTICES.txt']:
    if (root/name).exists():shutil.copyfile(root/name,contents/'Resources'/name)
if (root/'Docs/Start Here.html').exists():shutil.copyfile(root/'Docs/Start Here.html',contents/'Resources/Start Here.html')
sign=['codesign','--force','--deep','--sign',args.identity or '-']
if args.identity:sign+=['--options','runtime','--timestamp']
subprocess.run(sign+[str(app)],check=True)
subprocess.run(['codesign','--verify','--deep','--strict',str(app)],check=True)
print(app)
