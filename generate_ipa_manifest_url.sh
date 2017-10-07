#!/usr/bin/env python3
import contextlib
import datetime
import os
import plistlib
import re
import time
import zipfile
import dropbox
from ntpath import basename
from sys import argv

DROPBOX_ACCESS_TOKEN = "<YOUR ACCESS TOKEN>"


def get_ipa_meta(ipa_path):
    ipa_file = zipfile.ZipFile(ipa_path)
    plist_path = find_plist_path(ipa_file)
    plist_data = ipa_file.read(plist_path)
    plist_root = plistlib.loads(plist_data)

    display_name = plist_root['CFBundleDisplayName']
    bundle_id = plist_root['CFBundleIdentifier']
    version = plist_root['CFBundleShortVersionString']

    print('Display Name: %s' % display_name)
    print('Bundle Identifier: %s' % bundle_id)
    print('Version: %s' % version)
    print('')

    return display_name, version, bundle_id


def find_plist_path(zip_file):
    name_list = zip_file.namelist()
    pattern = re.compile(r'Payload/[^/]*.app/Info.plist')
    for path in name_list:
        m = pattern.match(path)
        if m is not None:
            return m.group()


def upload(dbx, path, overwrite=False):
    mode = (dropbox.files.WriteMode.overwrite
            if overwrite
            else dropbox.files.WriteMode.add)
    mtime = os.path.getmtime(path)
    file_name = basename(path)

    with open(path, 'rb') as f:
        data = f.read()

    try:
        print('Uploading "%s"...' % file_name)
        file_meta_data = dbx.files_upload(
            data, "/" + file_name, mode,
            client_modified=datetime.datetime(*time.gmtime(mtime)[:6]),
            mute=True)
        print('Creating shared link...')
        path_link_meta = dbx.sharing_create_shared_link(file_meta_data.path_display)
        url = path_link_meta.url.replace("www.dropbox.com", "dl.dropboxusercontent.com")[:-5]  # .replace("?dl=0", "")
        print('Direct URL is: ', url)
        return url
    except dropbox.exceptions.ApiError as err:
        print('*** API error', err)
        return None


def create_manifest(ipa_path, ipa_dropbox_url, ipa_meta):
    manifest_path = ipa_path.replace("ipa", "plist")

    assets_dic = dict(
        kind="software-package",
        url=ipa_dropbox_url
    )

    metadata_dic = dict(
        kind="software",
        title=ipa_meta[0]
    )
    metadata_dic['bundle-identifier'] = ipa_meta[2]
    metadata_dic['bundle-version'] = ipa_meta[1]

    pl = dict(
        items=[dict(
            assets=[assets_dic],
            metadata=metadata_dic
        )]
    )
    with open(manifest_path, 'wb') as fp:
        plistlib.dump(pl, fp)

    return manifest_path


if __name__ == '__main__':
    args = argv[1:]
    if len(args) < 1:
        print('Usage: python3 get_ipa_url.py /path/to/ipa')
    else:
        ipa_path = args[0]
        dbx = dropbox.Dropbox(DROPBOX_ACCESS_TOKEN)
        ipa_meta = get_ipa_meta(ipa_path)
        ipa_dropbox_url = upload(dbx, ipa_path, True)
        manifest_path = create_manifest(ipa_path, ipa_dropbox_url, ipa_meta)
        manifest_dropbox_url = upload(dbx, manifest_path, True)

        print('')
        print('Generated Link:')
        print('<a href="itms-services://?action=download-manifest&url=%s">%s</a>' % (manifest_dropbox_url, ipa_meta[0]))
