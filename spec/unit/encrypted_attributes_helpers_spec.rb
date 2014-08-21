# encoding: UTF-8
#
# Author:: Xabier de Zuazo (<xabier@onddo.com>)
# Copyright:: Copyright (c) 2014 Onddo Labs, SL. (www.onddo.com)
# License:: Apache License, Version 2.0
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

require 'spec_helper'
require 'encrypted_attributes_helpers'
require 'chef-encrypted-attributes'

# A recipe which includes EncryptedAttributesHelpers
class FakeRecipe
  include Chef::EncryptedAttributesHelpers
end

describe Chef::EncryptedAttributesHelpers do
  let(:helpers) { FakeRecipe.new }
  let(:node) { Chef::Node.new }
  before do
    Chef::Config[:solo] = false
    allow(helpers).to receive(:node).and_return(node)
    allow(helpers).to receive(:include_recipe).and_return(true)
  end

  context '#encrypted_attributes_enabled?' do

    it 'should return true by default' do
      expect(helpers.encrypted_attributes_enabled?).to eq(true)
    end

    it 'should return false with chef-solo' do
      Chef::Config[:solo] = true
      expect(helpers.encrypted_attributes_enabled?).to eq(false)
    end

    it 'should return false when node["dev_mode"] set' do
      node.set['dev_mode'] = true
      expect(helpers.encrypted_attributes_enabled?).to eq(false)
    end

  end

  context '#encrypted_attribute_read' do
    let(:secret) { 's3Cr3T' }
    before do
      node.set['ftp']['password'] = secret
      allow(Chef::EncryptedAttribute).to receive(:load).and_return('OK')
    end

    it 'should include encrypted_attributes recipe' do
      expect(helpers).to receive(:include_recipe).with('encrypted_attributes')
        .and_return(true)
      helpers.encrypted_attribute_read(%w(ftp password))
    end

    it 'should call EncryptedAttribute#load' do
      expect(Chef::EncryptedAttribute).to receive(:load).with(secret)
        .and_return('OK').once
      expect(helpers.encrypted_attribute_read(%w(ftp password))).to eq('OK')
    end

    it 'should not call EncryptedAttribute#load when disabled' do
      helpers.encrypted_attributes_enabled = false
      expect(Chef::EncryptedAttribute).to_not receive(:load)
      expect(helpers).to_not receive(:include_recipe)
      expect(helpers.encrypted_attribute_read(%w(ftp password))).to eq(secret)
    end

  end

  context '#encrypted_attribute_read_from_node' do
    let(:secret) { 's3Cr3T' }
    before do
      node.set['ftp']['password'] = secret
      allow(Chef::EncryptedAttribute).to receive(:load_from_node)
        .and_return('OK')
    end

    it 'should include encrypted_attributes recipe' do
      expect(helpers).to receive(:include_recipe).with('encrypted_attributes')
        .and_return(true)
      helpers.encrypted_attribute_read_from_node('node1', %w(ftp password))
    end

    it 'should call EncryptedAttribute#load_from_node' do
      expect(Chef::EncryptedAttribute).to receive(:load_from_node)
        .with('node1', %w(ftp password)).and_return('OK').once
      expect(
        helpers.encrypted_attribute_read_from_node('node1', %w(ftp password))
      ).to eq('OK')
    end

    it 'should not call EncryptedAttribute#load_from_node when disabled' do
      helpers.encrypted_attributes_enabled = false
      expect(Chef::EncryptedAttribute).to_not receive(:load_from_node)
      expect(helpers).to_not receive(:include_recipe)
      expect(
        helpers.encrypted_attribute_read_from_node('node1', %w(ftp password))
      ).to eq(nil)
    end

  end

  context '#encrypted_attribute_write' do
    let(:secret) { 's3Cr3T' }
    let(:encrypted) { '3NcrYpt3D' }
    before do
      node.set['ftp']['password'] = encrypted
      allow(node).to receive(:save)
      allow(Chef::EncryptedAttribute).to receive(:load).and_return('OK')
      allow(Chef::EncryptedAttribute).to receive(:exist?).and_return(false)
      allow(Chef::EncryptedAttribute).to receive(:create).and_return(encrypted)
      allow(Chef::EncryptedAttribute).to receive(:update).and_return(true)
    end

    it 'should include encrypted_attributes recipe' do
      expect(helpers).to receive(:include_recipe).with('encrypted_attributes')
        .and_return(true)
      helpers.encrypted_attribute_write(%w(ftp password)) { secret }
    end

    it 'should call EncryptedAttribute#exist?' do
      expect(Chef::EncryptedAttribute).to receive(:exist?).with(encrypted)
        .and_return(true).once
      helpers.encrypted_attribute_write(%w(ftp password)) { secret }
    end

    it 'should not call EncryptedAttribute#exist? when disabled' do
      helpers.encrypted_attributes_enabled = false
      expect(Chef::EncryptedAttribute).to_not receive(:exist?)
      helpers.encrypted_attribute_write(%w(ftp password)) { secret }
    end

    it 'should call EncryptedAttribute#create when does not exist' do
      expect(Chef::EncryptedAttribute).to receive(:exist?).with(encrypted)
        .and_return(false).once
      expect(Chef::EncryptedAttribute).to receive(:create).with(secret)
        .and_return(encrypted).once
      helpers.encrypted_attribute_write(%w(ftp password)) { secret }
    end

    it 'should return clear value when does not exist' do
      allow(Chef::EncryptedAttribute).to receive(:exist?).with(encrypted)
        .and_return(false)
      allow(Chef::EncryptedAttribute).to receive(:create).with(secret)
        .and_return(encrypted)
      expect(helpers.encrypted_attribute_write(%w(ftp password)) { secret })
        .to eq(secret)
    end

    it 'should call EncryptedAttribute#update when exist' do
      expect(Chef::EncryptedAttribute).to receive(:exist?).with(encrypted)
        .and_return(true).once
      expect(Chef::EncryptedAttribute).to receive(:update).with(encrypted)
        .and_return(true).once
      helpers.encrypted_attribute_write(%w(ftp password)) { secret }
    end

    it 'should call EncryptedAttribute#load when exist' do
      expect(Chef::EncryptedAttribute).to receive(:exist?).with(encrypted)
        .and_return(true).once
      expect(Chef::EncryptedAttribute).to receive(:update).with(encrypted)
        .and_return(true).once
      expect(Chef::EncryptedAttribute).to receive(:load).with(encrypted)
        .and_return(secret).once
      expect(helpers.encrypted_attribute_write(%w(ftp password)) { secret })
        .to eq(secret)
    end

  end

  context '#encrypted_attributes_allow' do

    it 'should set Chef::Config[:encrypted_attributes][:client_search]' do
      Chef::Config[:encrypted_attributes][:client_search] = nil
      helpers.encrypted_attributes_allow('SEARCH_QUERY')
      expect(Chef::Config[:encrypted_attributes][:client_search])
        .to eq('SEARCH_QUERY')
    end

  end

  context '#encrypted_attributes_enabled' do

    it 'should enable encrypted attributes when true' do
      helpers.encrypted_attributes_enabled = true
      expect(helpers.encrypted_attributes_enabled?).to eq(true)
    end

    it 'should disable encrypted attributes when false' do
      helpers.encrypted_attributes_enabled = false
      expect(helpers.encrypted_attributes_enabled?).to eq(false)
    end

  end

end