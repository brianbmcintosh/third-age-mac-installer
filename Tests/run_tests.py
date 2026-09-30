#!/usr/bin/env python3
from pathlib import Path
import argparse,bz2,json,os,platform,shutil,subprocess,tempfile,zlib

root=Path(__file__).resolve().parents[1]
parser=argparse.ArgumentParser()
parser.add_argument('--out',type=Path,default=root/'.test-build')
parser.add_argument('--archives',nargs=2,type=Path,help='Optional: perform full install using the two real downloads')
args=parser.parse_args();out=args.out.resolve();out.mkdir(parents=True,exist_ok=True)
sdk=subprocess.check_output(['xcrun','--sdk','macosx','--show-sdk-path'],text=True).strip()
arch='arm64' if platform.machine()=='arm64' else 'x86_64';target=f'{arch}-apple-macosx12.0'
env=dict(os.environ,CLANG_MODULE_CACHE_PATH=str(out/'module-cache'))
obj=out/'ArchiveIO.o'
subprocess.run(['xcrun','clang','-target',target,'-isysroot',sdk,'-O2','-c',str(root/'Sources/ArchiveIO.c'),'-o',str(obj)],check=True,env=env)
exe=out/'CoreTests'
subprocess.run(['xcrun','swiftc','-swift-version','5','-target',target,'-sdk',sdk,'-O','-module-cache-path',str(out/'module-cache'),'-import-objc-header',str(root/'Sources/ArchiveIO.h'),str(root/'Sources/Core.swift'),str(root/'Tests/CoreTests.swift'),str(obj),'-lz','-lbz2','-framework','CryptoKit','-o',str(exe)],check=True,env=env)

with tempfile.TemporaryDirectory(prefix='third-age-tests-',dir=out) as tmp:
    folder=Path(tmp)
    data=bytes(range(256))*2048+b'A'*1_000_000
    (folder/'expected.bin').write_bytes(data)
    (folder/'stored.bin').write_bytes(b'\0'+data)
    (folder/'zlib.bin').write_bytes(b'\1'+zlib.compress(data))
    (folder/'bz2.bin').write_bytes(b'\2'+bz2.compress(data))
    subprocess.run([str(exe),'selftest',str(folder)],check=True)
    if args.archives:
        game=folder/'Fake Steam Library with spaces'/'steamapps/common/Medieval II Total War'
        mods=game/'Medieval2Data/mods';mods.mkdir(parents=True)
        (game/'.third-age-test-fixture').write_text('Disposable integration fixture only\n')
        sentinel=mods/'existing-mod'/'saves'/'keep.sav';sentinel.parent.mkdir(parents=True);sentinel.write_bytes(b'Existing campaign must survive unchanged.\n')
        sources=[str(p.resolve()) for p in args.archives]
        # Cancel after data extraction begins: no final mod or temporary files may remain.
        subprocess.run([str(exe),'cancel',str(game),*sources],check=True)
        assert sentinel.read_bytes()==b'Existing campaign must survive unchanged.\n'
        subprocess.run([str(exe),'install',str(game),*sources],check=True)
        mod=mods/'third_age_3'
        report=json.loads((mod/'mac-installation.json').read_text())
        assert report['publisherFilesVerified']==18961
        assert (mod/'data/world/maps/campaign/imperial_campaign/descr_strat.txt').is_file()
        assert not list(mod.rglob('map.rwm'))
        assert not (mod/'data/sounds/music.dat').exists()
        assert 'mod = mods/third_age_3' in (mod/'default.cfg').read_text()
        assert all(p.name==p.name.lower() for p in (mod/'data').rglob('*'))
        assert sentinel.read_bytes()==b'Existing campaign must survive unchanged.\n'
        assert not list(mods.glob('.third-age-install-*'))
        report_before=(mod/'mac-installation.json').read_bytes()
        repeat=subprocess.run([str(exe),'install',str(game),*sources],capture_output=True,text=True)
        assert repeat.returncode!=0 and 'already present' in repeat.stderr
        assert (mod/'mac-installation.json').read_bytes()==report_before
        assert sentinel.read_bytes()==b'Existing campaign must survive unchanged.\n'
        (out/'integration-report.json').write_text(json.dumps({'status':'passed','architecture':arch,'publisher_checksums':18961,'checks':['stream decompression and bounds','unsafe paths','partial install cancellation and cleanup','complete real-archive installation','existing mod preservation','repeat install refused','lowercase assets','Mac configuration','Windows caches removed'],'installed_files_before_report':report['fileCount']},indent=2)+'\n')
        print('PASS: complete integration; existing game data preserved; repeat install refused',flush=True)
