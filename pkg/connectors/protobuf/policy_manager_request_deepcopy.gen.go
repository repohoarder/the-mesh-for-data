// Code generated by protoc-gen-gogo. DO NOT EDIT.
// source: policy_manager_request.proto

package connectors

import (
	fmt "fmt"
	proto "github.com/gogo/protobuf/proto"
	math "math"
)

// Reference imports to suppress errors if they are not otherwise used.
var _ = proto.Marshal
var _ = fmt.Errorf
var _ = math.Inf

// DeepCopyInto supports using DatasetIdentifier within kubernetes types, where deepcopy-gen is used.
func (in *DatasetIdentifier) DeepCopyInto(out *DatasetIdentifier) {
	p := proto.Clone(in).(*DatasetIdentifier)
	*out = *p
}

// DeepCopy is an autogenerated deepcopy function, copying the receiver, creating a new DatasetIdentifier. Required by controller-gen.
func (in *DatasetIdentifier) DeepCopy() *DatasetIdentifier {
	if in == nil {
		return nil
	}
	out := new(DatasetIdentifier)
	in.DeepCopyInto(out)
	return out
}

// DeepCopyInto supports using DatasetContext within kubernetes types, where deepcopy-gen is used.
func (in *DatasetContext) DeepCopyInto(out *DatasetContext) {
	p := proto.Clone(in).(*DatasetContext)
	*out = *p
}

// DeepCopy is an autogenerated deepcopy function, copying the receiver, creating a new DatasetContext. Required by controller-gen.
func (in *DatasetContext) DeepCopy() *DatasetContext {
	if in == nil {
		return nil
	}
	out := new(DatasetContext)
	in.DeepCopyInto(out)
	return out
}

// DeepCopyInto supports using ApplicationDetails within kubernetes types, where deepcopy-gen is used.
func (in *ApplicationDetails) DeepCopyInto(out *ApplicationDetails) {
	p := proto.Clone(in).(*ApplicationDetails)
	*out = *p
}

// DeepCopy is an autogenerated deepcopy function, copying the receiver, creating a new ApplicationDetails. Required by controller-gen.
func (in *ApplicationDetails) DeepCopy() *ApplicationDetails {
	if in == nil {
		return nil
	}
	out := new(ApplicationDetails)
	in.DeepCopyInto(out)
	return out
}

// DeepCopyInto supports using AccessOperation within kubernetes types, where deepcopy-gen is used.
func (in *AccessOperation) DeepCopyInto(out *AccessOperation) {
	p := proto.Clone(in).(*AccessOperation)
	*out = *p
}

// DeepCopy is an autogenerated deepcopy function, copying the receiver, creating a new AccessOperation. Required by controller-gen.
func (in *AccessOperation) DeepCopy() *AccessOperation {
	if in == nil {
		return nil
	}
	out := new(AccessOperation)
	in.DeepCopyInto(out)
	return out
}

// DeepCopyInto supports using ApplicationContext within kubernetes types, where deepcopy-gen is used.
func (in *ApplicationContext) DeepCopyInto(out *ApplicationContext) {
	p := proto.Clone(in).(*ApplicationContext)
	*out = *p
}

// DeepCopy is an autogenerated deepcopy function, copying the receiver, creating a new ApplicationContext. Required by controller-gen.
func (in *ApplicationContext) DeepCopy() *ApplicationContext {
	if in == nil {
		return nil
	}
	out := new(ApplicationContext)
	in.DeepCopyInto(out)
	return out
}
