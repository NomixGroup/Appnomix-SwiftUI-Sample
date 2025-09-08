#!/bin/bash

# Script: SetupXCode.sh
# Purpose: Automates the setup of an Xcode project with the Safari Extension, Swift package dependencies, and app groups
# Author: Appnomix LLC
# Date: March 20, 2025
# Usage: ./SetupXCode.sh [xcode_project_path] (if not provided, the script uses its own directory)
# Requirements: macOS, Xcode, Ruby, Homebrew (for Ruby installation), sips (for image resizing)
# Notes: Ensure the variables below are updated with the correct values

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
PROJECT_PATH="${1:-$SCRIPT_DIR}"

# ---------------------------------------------------------
# TODO: These variables should be updated by the client
# ---------------------------------------------------------
APP_GROUPS_NAME=group.app.appnomix.demo-swiftui # (e.g., group.com.example.app)
LOGO_PNG_PATH="logo.png"
XC_VERSION=2.0.0-beta03 # SDK version (see: https://github.com/NomixGroup/ios_commerce_sdk_binary/releases)

XC_FRAMEWORK_NAME="AppnomixCommerce"
TEMPLATE_URL="https://github.com/NomixGroup/ios_commerce_sdk_binary/releases/download/$XC_VERSION/Appnomix.Safari.Extension.xctemplate.zip"
SWIFT_PACKAGE_URL="https://github.com/NomixGroup/ios_commerce_sdk_binary"

# Validate critical variables
if [ -z "$APP_GROUPS_NAME" ] || [ "$APP_GROUPS_NAME" = "YOUR_APP_GROUPS_NAME_HERE" ]; then
    echo "❌ Error: APP_GROUPS_NAME is not set. Please update APP_GROUPS_NAME with a valid value."
    exit 1
fi

if [ ! -f "$LOGO_PNG_PATH" ]; then
    echo "❌ Error: Logo file '$LOGO_PNG_PATH' not found. Please provide a valid logo.png file."
    exit 1
fi

# Find the .xcodeproj file in the current directory
cd "$PROJECT_PATH"
XCODEPROJ_FILE=$(find . -name "*.xcodeproj" -maxdepth 1 -type d)

# Check if exactly one .xcodeproj file was found
  if [ -z "$XCODEPROJ_FILE" ]; then
      echo "Error: No .xcodeproj file found in the current directory."
      exit 1
  elif [ $(echo "$XCODEPROJ_FILE" | wc -l) -gt 1 ]; then
      echo "Error: Multiple .xcodeproj files found in the current directory."
      exit 1
  fi

# Set variables
  XCODE_VERSION=$(xcodebuild -version | grep "Xcode")
  BUNDLE_ID=$(xcodebuild -showBuildSettings | grep -w PRODUCT_BUNDLE_IDENTIFIER | awk '{ print $3 }')
  TARGET_NAME=$(basename "$XCODEPROJ_FILE" .xcodeproj)
  APP_EXTENSION_NAME="$TARGET_NAME Extension"
  APP_EXTENSION_DIR_PATH="$PROJECT_PATH/$APP_EXTENSION_NAME"

# Display project information
  echo "📋 App Group is set to: $APP_GROUPS_NAME"
  echo "📋 Using Xcode version: $XCODE_VERSION"
  echo "📋 Found TARGET_NAME=$TARGET_NAME"
  echo "📋 Found BUNDLE_ID=$BUNDLE_ID"
  echo "📋 XCODEPROJ_FILE: $XCODEPROJ_FILE"


# ------------------------------
# Function Definitions
# ------------------------------

download_safari_extension() {
  local TEMPLATE_URL="$1"
  local APP_GROUPS_NAME="$2"
  local APP_EXTENSION_DIR_PATH="$3"

  local XC_TEMPLATE_NAME="Appnomix.Safari.Extension.xctemplate"
  local TEMP_DIR=$(mktemp -d)

  cd "$TEMP_DIR" || { echo "Error: Cannot change directory to $TEMP_DIR"; exit 1; }

  echo "ℹ️ Downloading Safari Extension from $TEMPLATE_URL"
  if ! curl -s -L -o "output.zip" "$TEMPLATE_URL" --fail; then
      echo "❌ Error: Failed to download $TEMPLATE_URL"
      rm -rf "$TEMP_DIR"
      exit 1
  fi

  if ! unzip -q "output.zip"; then
      echo "Error: Failed to unzip $XC_TEMPLATE_NAME.zip"
      rm -rf "$TEMP_DIR"
      exit 1
  fi
  echo "✅ Safari Extension downloaded and unzipped successfully."

  echo "[AppGroups] Set $APP_GROUPS_NAME as App Groups name"

  # Replace the placeholder in specific files
  find "$XC_TEMPLATE_NAME" \( -name 'SafariWebExtensionHandler.swift' -o -name 'Appnomix Extension.entitlements' \) -type f | while read -r file; do
      echo "[AppGroups] Processing file: $file"
      sed -i '' -e "s/group\.YOUR_APP_GROUPS_NAME/$APP_GROUPS_NAME/g" "$file"
  done

  # Remove existing app_extension_dir_path folder if it exists
  if [ -d "$APP_EXTENSION_DIR_PATH" ] && [[ "$APP_EXTENSION_DIR_PATH" == "$PROJECT_PATH/"* ]]; then
      echo "⚠️ Replacing old extension folder at $APP_EXTENSION_DIR_PATH..."
      rm -rf "$APP_EXTENSION_DIR_PATH"
  fi

  # Recreate the directory and copy the files
  mkdir -p "$APP_EXTENSION_DIR_PATH"
  cp "$XC_TEMPLATE_NAME/Appnomix Extension.entitlements" "$APP_EXTENSION_DIR_PATH/"
  cp "$XC_TEMPLATE_NAME"/*.swift "$APP_EXTENSION_DIR_PATH/"
  cp "$XC_TEMPLATE_NAME/Info.plist" "$APP_EXTENSION_DIR_PATH/Info.plist"
  cp -r "$XC_TEMPLATE_NAME/Resources" "$APP_EXTENSION_DIR_PATH/"

  echo "🎉 Safari Extension files we added successfully."
  echo ""
  rm -rf "$TEMP_DIR"
}

add_new_target_with_template() {
    
    local project_path="$1" # path to your .xcodeproj file
    local template_target_name="$2" # name of the existing target to duplicate (template)
    local app_extension_dir_path="$3" # path of the new app extension dir
    local new_target_name="$template_target_name Extension" # new target name with " Extension" appended
    
    ruby -e "$(cat <<EOF
require 'xcodeproj'
require 'plist'

target_name = '$template_target_name'
extension_name = '$template_target_name Extension'

# Path to your .xcodeproj file
project_path = '$project_path'

# Open the Xcode project
project = Xcodeproj::Project.open(project_path)

# Find the template target to use as a reference
template_target = project.targets.find { |target| target.name == "#{target_name}" }
if template_target.nil?
  puts '❌ Error: Template target "#{target_name}" not found in "#{project_path}"'
  exit 1
end

# Check if the new target already exists
existing_target = project.targets.find { |target| target.name == "#{extension_name}" }
if existing_target
  puts "⚠️ Target '#{extension_name}' already exists. Skipping creation."
  new_target = existing_target
else
  # Duplicate the template target to create a new target
  platform_name = template_target.platform_name.to_s.empty? ? :ios : template_target.platform_name.to_sym

  new_target = project.new_target(:app_extension, extension_name, platform_name, template_target.deployment_target)

  # Add the extension target as a dependency to the main target
  template_target.add_dependency(new_target)
end

# Get the path to the .xctemplate directory
template_dir = File.expand_path('$app_extension_dir_path')
if !Dir.exist?(template_dir)
  puts '❌ Error: Template directory "#{template_dir}" not found.'
  exit 1
end

# versioning - begin
current_project_version = '1.0'
marketing_version = '1.0'

info_plist_file_setting = template_target.resolved_build_setting('INFOPLIST_FILE')
info_plist_file = if info_plist_file_setting.is_a?(Hash)
  info_plist_file_setting['Release'] || info_plist_file_setting.values.first
else
  info_plist_file_setting
end

# Read and parse the Info.plist file
if info_plist_file.nil? || !File.exist?(info_plist_file)
  puts "❌ Error: Info.plist file not found for the target #{target_name}"
else 
  # Parse the plist and fetch version
  plist = Plist.parse_xml(info_plist_file)
  current_project_version = plist['CFBundleVersion']
  marketing_version = plist['CFBundleShortVersionString']
end

# Fallback: Read version from Xcode build settings if missing
if current_project_version.nil?
  current_project_version = template_target.resolved_build_setting('CURRENT_PROJECT_VERSION')
  current_project_version = current_project_version.is_a?(Hash) ? current_project_version['Release'] || current_project_version.values.first : current_project_version || '1.0'
end
if marketing_version.nil?
  marketing_version = template_target.resolved_build_setting('MARKETING_VERSION')
  marketing_version = marketing_version.is_a?(Hash) ? marketing_version['Release'] || marketing_version.values.first : marketing_version || '1.0'
end

puts "ℹ️ [Versioning] Found CFBundleVersion: #{current_project_version}, CFBundleShortVersionString: #{marketing_version}"
# versioning - end

# Get the project main group
template_group = project.main_group.find_subpath(extension_name, true)
template_group.set_source_tree('<group>')

path_resources = File.join(template_dir, 'Resources')
existing_resource_refs = template_group.files.select { |f| f.path.include?("/Resources/") }

# Remove missing files
existing_resource_refs.each do |file_ref|
  full_path = File.expand_path(file_ref.path, '$app_extension_dir_path/../')
  unless File.exist?(full_path)
    puts "✅ Removed missing resource: #{file_ref.path}"
    template_group.remove_reference(file_ref)
    new_target.resources_build_phase.remove_file_reference(file_ref)
  end
end

# Copy Bundle Resources
Dir.foreach(path_resources) do |entry|
  next if entry == '.' || entry == '..' || entry == '.DS_Store' || entry == 'Info.plist' || entry == 'Appnomix Extension.entitlements'
  path = File.join(path_resources, entry)

  # Check if the reference already exists in the group
  existing_ref = template_group.files.find { |f| f.path && f.path.end_with?("/Resources/#{entry}") }
  if existing_ref
    #puts "⚠️ Skipped existing file: #{entry} (already added to group)"
  else
    existing_ref = template_group.new_reference(path)
    puts "✅ Added file reference #{entry} to group #{template_group.name}"
  end

  # Check if the file is already added to the target
  existing_target_resource = new_target.resources_build_phase.files_references.find { |r| r.path && r.path.end_with?(entry) }
  if existing_target_resource
    #puts "⚠️ Skipped existing file: #{entry} as bundle resource (already added to target)"
  else
    new_target.add_resources([existing_ref])
    puts "✅ Added file #{entry} as bundle resource to target #{new_target.name}"
  end
end

# Add swift files to Compile Sources
Dir.foreach(template_dir) do |entry|
  next if entry == '.' || entry == '..' || entry == '.DS_Store' || entry == 'Info.plist' || entry == 'Appnomix Extension.entitlements'
  if entry.end_with?('.swift')
    path = File.join(template_dir, entry)
    existing_file_ref = template_group.files.find { |f| f.path == path }
    existing_file_ref = template_group.files.find { |f| f.path && f.path.end_with?(entry) }
    unless existing_file_ref
      file_ref = template_group.new_file(path)
      new_target.add_file_references([file_ref])
      puts "✅ Added file #{entry} as compile source to #{template_group.name}"
    else
      puts "⚠️ Skipped existing file: #{entry} as compile source"
    end
  end
end

development_team = template_target.build_settings('Debug')['DEVELOPMENT_TEAM'] || template_target.build_settings('Release')['DEVELOPMENT_TEAM']

new_target.build_configurations.each do |config|
  config.build_settings['SWIFT_VERSION'] = '5.0'
  config.build_settings['GENERATE_INFOPLIST_FILE'] = 'YES'
  config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '15.0'
  config.build_settings['PRODUCT_NAME'] = extension_name
  config.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = "$BUNDLE_ID.appnomixextension"
  config.build_settings['CURRENT_PROJECT_VERSION'] = current_project_version
  config.build_settings['MARKETING_VERSION'] = marketing_version
  config.build_settings['DEVELOPMENT_TEAM'] = development_team
  config.build_settings['INFOPLIST_FILE'] = "$APP_EXTENSION_NAME/Info.plist"
  config.build_settings['INFOPLIST_KEY_CFBundleDisplayName'] = extension_name
  config.build_settings['OTHER_LDFLAGS'] = [
    '-framework',
    'SafariServices'
  ]
end

new_target.product_type = 'com.apple.product-type.app-extension'

# Save the changes to the Xcode project file
project.save

puts "🎉 Successfully added new target '#{extension_name}' based on template '#{target_name}' to '#{project_path}'"
puts ""
EOF
    )"
}

add_privacy_permissions() {
    ruby <<EOF
require 'xcodeproj'
require 'plist'

project_path = '$1' # Xcode project path

# Open the Xcode project
project = Xcodeproj::Project.open(project_path)

# Find the main application target (ignores extensions, frameworks, etc.)
main_target = project.targets.find { |t| t.product_type == "com.apple.product-type.application" }

if main_target.nil?
  puts "❌ Error: No main application target found in the project."
  exit 1
end

# Retrieve the Info.plist file path from the target's build settings
info_plist_setting = main_target.resolved_build_setting("INFOPLIST_FILE")

info_plist_path = if info_plist_setting.is_a?(Hash)
  info_plist_setting["Release"] || info_plist_setting.values.first
else
  info_plist_setting
end

if info_plist_path.nil?
  puts "❌ Error: Could not determine Info.plist file location for target '#{main_target.name}'."
  exit 1
end

# Resolve absolute path
info_plist_path = File.expand_path(File.join(File.dirname(project_path), info_plist_path))

# Modify the Info.plist file
if File.exist?(info_plist_path)
  plist = Plist.parse_xml(info_plist_path)

  puts "✅ Adding permissions to #{info_plist_path}"
  
  # Define privacy descriptions
  privacy_descriptions = {
    # "NSLocationWhenInUseUsageDescription" => "Find exclusive deals and discounts in your area",
    # "NSLocationAlwaysUsageDescription" => "Find exclusive deals and discounts in your area",
    "NSUserTrackingUsageDescription" => "We will use your data to provide a better and personalized ad experience."
  }

  privacy_descriptions.each do |key, value|
    if plist.key?(key)
      puts "⚠️ #{key} is already defined: [#{plist[key]}]"
    else
      plist[key] = value
      puts "✅ Added #{key} to #{info_plist_path}"
    end
  end

  # Write the updated plist back to file
  File.write(info_plist_path, plist.to_plist)

else
  puts "❌ Error: Info.plist file not found at #{info_plist_path}"
  exit 1
end

puts "🎉 Privacy permissions updated successfully."

EOF
}

ensure_app_groups_exists() {
    ruby <<EOF
require 'xcodeproj'
require 'plist'

project_path = '$1' # project file
target_name = '$2' # target name
entitlements_file_path = '$3' # entitlements path
app_groups_name = '$4' # app group name to add

puts "[AppGroups] Start searching CODE_SIGN_ENTITLEMENTS for target: #{target_name}"

# Open the Xcode project
project = Xcodeproj::Project.open(project_path)

# Find the target
target = project.targets.find { |t| t.name == target_name }
if target.nil?
  puts "Target #{target_name} not found"
  exit 1
end

current_entitlements_file_path = ''

# Check if CODE_SIGN_ENTITLEMENTS is already set in the build settings
target.build_configurations.each do |config|
  current_entitlements_file_path = config.build_settings['CODE_SIGN_ENTITLEMENTS']
  puts "[AppGroups] Searching in configuration: #{config.name}"

  if current_entitlements_file_path && !current_entitlements_file_path.empty?
    puts "[AppGroups] Found entitlements file: #{current_entitlements_file_path} in configuration: #{config.name}"
    break
  end
end

if current_entitlements_file_path.nil? || current_entitlements_file_path.empty?
  current_entitlements_file_path = entitlements_file_path
  puts "[AppGroups] CODE_SIGN_ENTITLEMENTS not set. Using default path: #{current_entitlements_file_path}"
else
  
end

# Initialize entitlements hash
entitlements = {}

# Load entitlements from file if it exists
if File.exist?(current_entitlements_file_path)
  begin
    entitlements = Plist.parse_xml(current_entitlements_file_path)
    entitlements ||= {}  # Ensure entitlements is not nil
  rescue StandardError => e
    puts "❌ Error loading entitlements file: #{e.message}"
    exit 1
  end
else
  puts "[AppGroups] Entitlements file not found at #{current_entitlements_file_path}, creating a new one."
  current_entitlements_file_path = entitlements_file_path
end

# Ensure 'com.apple.security.application-groups' is initialized as an array
entitlements['com.apple.security.application-groups'] ||= []

puts "[AppGroups] Current entitlements: #{entitlements}"

# Check if app_groups_name already exists in entitlements
if entitlements['com.apple.security.application-groups'].include?(app_groups_name)
  puts "[AppGroups] App group #{app_groups_name} already exists in entitlements."
else
  # Add app_groups_name to the array if it does not exist
  entitlements['com.apple.security.application-groups'] << app_groups_name
  puts "[AppGroups] App group #{app_groups_name} added to entitlements."

  # Write the updated entitlements back to the file
  begin
    File.open(current_entitlements_file_path, 'w') do |file|
      file.write(entitlements.to_plist)
    end
    puts "✅ [AppGroups] Entitlements successfully updated."
  rescue StandardError => e
    puts "❌ Error writing entitlements file: #{e.message}"
    exit 1
  end
end

puts "[AppGroups] Updated entitlements: #{entitlements}"

# Ensure the entitlements file is set in the build settings if not already set
target.build_configurations.each do |config|
  config.build_settings['CODE_SIGN_ENTITLEMENTS'] = current_entitlements_file_path
  puts "[AppGroups] CODE_SIGN_ENTITLEMENTS set to: #{current_entitlements_file_path} for configuration: #{config.name}"
end

# Save the project
project.save

puts "🎉 [AppGroups] App group #{app_groups_name} successfully ensured for target #{target_name} to #{current_entitlements_file_path}."
puts ""
EOF
}

add_copy_files_build_phase() {
    ruby <<EOF
  require 'xcodeproj'

  project_path = '$1' # 1 = project file
  target_name = '$2'
  build_phase_name = '$3'
  dst_subfolder_spec ='$4'
  dst_path = '$5'
  files = $6

  # Open the Xcode project
  project = Xcodeproj::Project.open(project_path)

  # Find the target by name
  target = project.targets.find { |t| t.name == target_name }

  if target.nil?
    puts "❌ Error: Target #{target_name} not found in project."
    exit 1
  end

  # Create a new Copy Files build phase if it doesn't exist
  copy_files_phase = target.build_phases.find { |phase| phase.display_name == build_phase_name }
  if copy_files_phase
    puts "Build phase '#{build_phase_name}' already exists"
  else
    copy_files_phase = project.new(Xcodeproj::Project::Object::PBXCopyFilesBuildPhase)
    copy_files_phase.name = build_phase_name
    copy_files_phase.dst_subfolder_spec = dst_subfolder_spec
    copy_files_phase.dst_path = dst_path
    puts "Created new build phase '#{build_phase_name}'"

    # Add it to the first available position to avoid conflict with Firebase Run Script
    target.build_phases.unshift(copy_files_phase)
  end

  # Add files to the Copy Files build phase
  files.each do |file_path|
    file_ref = project.main_group.find_file_by_path(file_path) || project.main_group.new_file(file_path)
    file_ref.source_tree = 'BUILT_PRODUCTS_DIR'
    unless copy_files_phase.files_references.include?(file_ref)
      copy_files_phase.add_file_reference(file_ref)
      puts "Added file #{file_path} to '#{build_phase_name}' build phase."
    else
      puts "File #{file_path} already exists in '#{build_phase_name}' build phase."
    end
  end

  # Save the project
  project.save
  puts "🎉 Successfully added Copy Files build phase '#{build_phase_name}' to target #{target_name}."
  puts ""
EOF
}

update_extension_name() {
    ruby <<EOF
require 'json'
require 'plist'
require 'xcodeproj'

  project_path = '$1' # project path 
  json_path = '$2' # messages.json path
  target_name = '$3'
  new_extension_name = '$4'

  # Open the Xcode project
  project = Xcodeproj::Project.open(project_path)

  # Find the main target
  target = project.targets.find { |t| t.name == target_name }
  if target.nil?
    puts "❌ Target '#{target_name}' not found!"
    exit 1
  end

  info_plist_file_setting = target.resolved_build_setting('INFOPLIST_FILE')
  info_plist_path = if info_plist_file_setting.is_a?(Hash)
    info_plist_file_setting['Release'] || info_plist_file_setting.values.first
  else
    info_plist_file_setting
  end

  puts "ℹ️ Getting extension name from Info.plist: #{info_plist_path}"

  # Read PRODUCT_NAME from build settings
  product_name_setting = target.resolved_build_setting('PRODUCT_NAME')
  product_name = if product_name_setting.is_a?(Hash)
    product_name_setting['Release'] || product_name_setting.values.first
  else
    product_name_setting
  end

  # Resolve TARGET_NAME if present
  if product_name == '\$(TARGET_NAME)'
    product_name = target.name
  end

  # Get bundle display name from the Info.plist file
  if info_plist_path.nil? || !File.exist?(info_plist_path)
    new_extension_name = product_name unless product_name.nil? || product_name.empty?
    puts "⚠️ File not found #{info_plist_path}"
  else
    plist = Plist.parse_xml(info_plist_path)   
    if plist.key?('CFBundleDisplayName')
      new_extension_name = plist['CFBundleDisplayName']
      puts "✅ New extension name found #{new_extension_name}"
    else
      new_extension_name = product_name unless product_name.nil? || product_name.empty?
      puts "⚠️ CFBundleDisplayName not found in #{info_plist_path}"
    end
  end

  puts "ℹ️ Opening JSON file #{json_path}..."

  # Read the JSON file
  json_content = File.read(json_path)
  
  # Parse the JSON
  data = JSON.parse(json_content)
  
  # Update the extension_name.message value
  if data['extension_name'] && data['extension_name']['message']
    data['extension_name']['message'] = new_extension_name
    puts "✅ Updating extension name to #{new_extension_name}"
  else
    puts "❌ extension_name or extension_name.message not found in JSON"
    return
  end

  # Convert the updated hash back to JSON
  updated_json_content = JSON.pretty_generate(data)

  # Write the updated JSON back to the file
  File.open(json_path, 'w') do |file|
    file.write(updated_json_content)
  end

  puts "🎉 Successfully updated extension_name.message to '#{new_extension_name}'"
  puts ""
EOF
}


copy_logo_image() {
    local input_image_path="$1"
    local output_image_base_path="$2"
    local output_image_base_name="$3"
    local sizes=($4)

    # Check if the source file exists
    if [ ! -f "$input_image_path" ]; then
        echo "❌ Error: Source image '$input_image_path' not found. Exiting..."
        return 1
    fi

    echo "ℹ️ Replacing branded logo..."
    for size in "${sizes[@]}"; do
        output_image_path="${output_image_base_path}/${output_image_base_name}-${size}.png"
        sips -z "$size" "$size" "$input_image_path" --out "$output_image_path" > /dev/null 2>&1
        echo "✅ Created logo ${output_image_path}"
    done

    echo "🎉 Successfully replaced branded logo."
    echo ""
}


# Example Usage:
# link_swift_package_binary_to_target "Demo SwiftUI.xcodeproj" "https://github.com/NomixGroup/ios_commerce_sdk_binary" "AppnomixCommerce" "Demo SwiftUI" "1.4"
link_swift_package_binary_to_target() {
    local XCODEPROJ_PATH="$1"
    local PACKAGE_URL="$2"
    local PRODUCT_NAME="$3"
    local TARGET_NAME="$4"
    local EXACT_VERSION="$5"

    # Ensure the version format is correct (e.g., "1.4" -> "1.4.0")
    if [[ "$EXACT_VERSION" =~ ^[0-9]+\.[0-9]+$ ]]; then
        EXACT_VERSION="${EXACT_VERSION}.0"
    fi

    echo "🔄 Linking remote Swift package at '$PACKAGE_URL' ($PRODUCT_NAME) ($EXACT_VERSION) to target '$TARGET_NAME' in project '$XCODEPROJ_PATH'..."

    ruby <<EOF
require 'xcodeproj'

project_path = "$XCODEPROJ_PATH"
package_url = "$PACKAGE_URL"
product_name = "$PRODUCT_NAME"
target_name = "$TARGET_NAME"
exact_version = "$EXACT_VERSION"

# Open the Xcode project
project = Xcodeproj::Project.open(project_path)

# Find the target
target = project.targets.find { |t| t.name == target_name }
if target.nil?
  puts "❌ Target '#{target_name}' not found!"
  exit 1
end

# Ensure package references exist
project.root_object.attributes["PackageReferences"] ||= []

# Find or create the package reference
package_reference = project.root_object.package_references.find { |pkg| pkg.repositoryURL == package_url }
unless package_reference
  package_reference = project.new(Xcodeproj::Project::Object::XCRemoteSwiftPackageReference)
  package_reference.repositoryURL = package_url
  package_reference.requirement = { "kind" => "exactVersion", "version" => exact_version }

  project.root_object.package_references << package_reference
  puts "✅ Added new package reference for '#{package_url}'"
else
  package_reference.requirement = { "kind" => "exactVersion", "version" => exact_version }
  puts "⚠️ Package reference for '#{package_url}' already exists"
end

# Check for existing product dependency
product_dependencies = project.objects.select { |obj| obj.isa == "XCSwiftPackageProductDependency" }
product_dependency = product_dependencies.find { |obj| obj.product_name == product_name }

unless product_dependency
  product_dependency = project.new(Xcodeproj::Project::Object::XCSwiftPackageProductDependency)
  product_dependency.product_name = product_name
  product_dependency.package = package_reference
  project.objects << product_dependency
  puts "✅ Created XCSwiftPackageProductDependency for '#{product_name}'"
end

# Add to Link Binary With Libraries using productRef
frameworks_build_phase = target.frameworks_build_phase || target.new_frameworks_build_phase

# Check if the product is already in the frameworks build phase
build_file = frameworks_build_phase.files.find { |bf| bf.respond_to?(:product_ref) && bf.product_ref == product_dependency }
unless build_file
  build_file = project.new(Xcodeproj::Project::Object::PBXBuildFile)
  build_file.product_ref = product_dependency  # Use product_ref instead of file_ref
  frameworks_build_phase.files << build_file
  puts "✅ Added '#{product_name}' to Link Binary With Libraries (using productRef)"
else
  puts "⚠️ '#{product_name}' already exists in Link Binary With Libraries"
end

# Save changes
project.save
puts "🎉 Successfully processed remote Swift package '#{product_name}' for target '#{target_name}'"
puts ""
EOF
}


# ------------------------------------
# Setup dependencies helper functions
# ------------------------------------

  # check if Ruby is installed
  check_ruby_installed() {
    if command -v ruby >/dev/null 2>&1; then
      echo "✅ Ruby is already installed."
      return 0
    else
      echo "⚠️ Ruby is not installed."
      return 1
    fi
  }

  # ensure required gems are installed
  ensure_gems_installed() {
    GEMS=("xcodeproj" "plist" "json")

    for GEM in "${GEMS[@]}"; do
      if gem list -i "$GEM" >/dev/null 2>&1; then
        echo "✅ Gem '$GEM' is already installed. Checking for updates..."
        gem update "$GEM"
      else
        echo "ℹ️ Installing gem '$GEM'..."
        gem install "$GEM"
        gem install "$GEM" --user-install
      fi
    done
  }

  # install Ruby on macOS
  install_ruby() {
    echo "ℹ️ Installing Ruby..."
    if ! command -v brew >/dev/null 2>&1; then
      echo "⚠️ Homebrew is not installed. Installing Homebrew first..."
      /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    fi
    brew install ruby
    echo "✅ Ruby installation completed."

    # Ensure the required gems are installed
    ensure_gems_installed
  }


# ------------------------------
# Main Code
# ------------------------------

main() {

  # Setup dependencies
  echo "Checking dependencies..."
  if check_ruby_installed; then
    ensure_gems_installed
  else
    install_ruby
  fi

  download_safari_extension "$TEMPLATE_URL" "$APP_GROUPS_NAME" "$APP_EXTENSION_DIR_PATH"
  cd "$PROJECT_PATH"

  add_new_target_with_template "$XCODEPROJ_FILE" "$TARGET_NAME" "$APP_EXTENSION_DIR_PATH"

  link_swift_package_binary_to_target "$XCODEPROJ_FILE" "$SWIFT_PACKAGE_URL" "AppnomixCommerce" "$TARGET_NAME" "$XC_VERSION"
  link_swift_package_binary_to_target "$XCODEPROJ_FILE" "$SWIFT_PACKAGE_URL" "AppnomixCommerce" "$APP_EXTENSION_NAME" "$XC_VERSION"

  add_privacy_permissions "$PROJECT_PATH/$XCODEPROJ_FILE"
  ensure_app_groups_exists "$PROJECT_PATH/$XCODEPROJ_FILE" "$TARGET_NAME" "$TARGET_NAME/$TARGET_NAME.entitlements" "$APP_GROUPS_NAME"
  ensure_app_groups_exists "$PROJECT_PATH/$XCODEPROJ_FILE" "$APP_EXTENSION_NAME" "$APP_EXTENSION_NAME/Appnomix Extension.entitlements" "$APP_GROUPS_NAME"

  add_copy_files_build_phase "$XCODEPROJ_FILE" "$TARGET_NAME" "Embed Foundation Extensions" '13' "" "['$APP_EXTENSION_NAME.appex']"
  update_extension_name "$PROJECT_PATH/$XCODEPROJ_FILE" "$APP_EXTENSION_DIR_PATH/Resources/_locales/en/messages.json" "$TARGET_NAME" "Appnomix Extension"
  copy_logo_image "$LOGO_PNG_PATH" "$APP_EXTENSION_DIR_PATH/Resources/images" "icon" "48 64 96 128 256 512"
  copy_logo_image "$LOGO_PNG_PATH" "$APP_EXTENSION_DIR_PATH/Resources/images" "toolbar-icon" "16 19 32 38 48 72"

  echo "done 😀"
}

main "$@"
