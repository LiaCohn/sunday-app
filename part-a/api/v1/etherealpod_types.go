package v1

import (
	corev1 "k8s.io/api/core/v1" //Kubernetes’ built-in types like Pod, PodSpec, etc.
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1" //contains metadata primitives like name, namespace, labels, annotations, etc.
)

// EtherealPodSpec defines the desired state of EtherealPod
type EtherealPodSpec struct {
	// Template describes the Pod that will be created
	// +kubebuilder:validation:Required
	Template corev1.PodTemplateSpec `json:"template"`
}

// EtherealPodStatus defines the observed state of EtherealPod
type EtherealPodStatus struct {
	// PodName is the name of the managed Pod
	PodName string `json:"podName,omitempty"`

	// RestartCount is the total number of container restarts
	RestartCount int32 `json:"restartCount"`
}

// +kubebuilder:object:root=true
// +kubebuilder:subresource:status
// +kubebuilder:printcolumn:name="RESTARTS",type="integer",JSONPath=".status.restartCount"
// +kubebuilder:printcolumn:name="AGE",type="date",JSONPath=".metadata.creationTimestamp"

// EtherealPod is the Schema for the etherealpods API
type EtherealPod struct {
	metav1.TypeMeta   `json:",inline"`
	metav1.ObjectMeta `json:"metadata,omitempty"`

	Spec   EtherealPodSpec   `json:"spec,omitempty"`
	Status EtherealPodStatus `json:"status,omitempty"`
}

// +kubebuilder:object:root=true

// EtherealPodList contains a list of EtherealPod
type EtherealPodList struct {
	metav1.TypeMeta `json:",inline"`
	metav1.ListMeta `json:"metadata,omitempty"`
	Items           []EtherealPod `json:"items"`
}

func init() {
	SchemeBuilder.Register(&EtherealPod{}, &EtherealPodList{})
}
