package controllers

import (
	"context"

	corev1 "k8s.io/api/core/v1"
	"k8s.io/apimachinery/pkg/api/errors"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/apimachinery/pkg/runtime"
	ctrl "sigs.k8s.io/controller-runtime"
	"sigs.k8s.io/controller-runtime/pkg/client"
	"sigs.k8s.io/controller-runtime/pkg/controller/controllerutil"
	"sigs.k8s.io/controller-runtime/pkg/log"

	sundayv1 "sunday.example.com/api/v1"
)

// EtherealPodReconciler reconciles an EtherealPod object
type EtherealPodReconciler struct {
	client.Client
	Scheme *runtime.Scheme
}

//+kubebuilder:rbac:groups=sunday.example.com,resources=etherealpods,verbs=get;list;watch;create;update;patch;delete
//+kubebuilder:rbac:groups=sunday.example.com,resources=etherealpods/status,verbs=get;update;patch
//+kubebuilder:rbac:groups="",resources=pods,verbs=get;list;watch;create;update;patch;delete

func (r *EtherealPodReconciler) Reconcile(ctx context.Context, req ctrl.Request) (ctrl.Result, error) {
	logger := log.FromContext(ctx)

	ep := &sundayv1.EtherealPod{} // Creates an empty object
	if err := r.Get(ctx, req.NamespacedName, ep); err != nil {
		if errors.IsNotFound(err) {
			return ctrl.Result{}, nil
		}
		return ctrl.Result{}, err
	}

	pod, err := r.getOrCreatePod(ctx, ep)
	if err != nil {
		logger.Error(err, "failed to reconcile Pod")
		return ctrl.Result{}, err
	}

	r.updateStatus(ctx, ep, pod)

	return ctrl.Result{}, nil
}

func (r *EtherealPodReconciler) getOrCreatePod(
	ctx context.Context,
	ep *sundayv1.EtherealPod,
) (*corev1.Pod, error) {

	podList := &corev1.PodList{} // list of pods in the namespace
	if err := r.List(ctx, podList, client.InNamespace(ep.Namespace)); err != nil {
		return nil, err
	}

	var ownedPods []*corev1.Pod
	for i := range podList.Items { // iterate over the pods
		pod := &podList.Items[i]
		//Is this Pod owned by THIS EtherealPod
		if metav1.IsControlledBy(pod, ep) {
			//If the Pod failed or succeeded (finished), delete it immediately
			if pod.Status.Phase == corev1.PodFailed || pod.Status.Phase == corev1.PodSucceeded {
				_ = r.Delete(ctx, pod) // delete the pod
				continue
			}
			// Collect all running/pending pods owned by this EtherealPod
			ownedPods = append(ownedPods, pod)
		}
	}

	// If multiple pods exist, delete extras (keep only the first one)
	if len(ownedPods) > 1 {
		for i := 1; i < len(ownedPods); i++ {
			_ = r.Delete(ctx, ownedPods[i])
		}
		return ownedPods[0], nil
	}

	// If exactly one pod exists, return it
	if len(ownedPods) == 1 {
		return ownedPods[0], nil
	}

	// If no pods exist, create a new one
	return r.createPod(ctx, ep)
}

func (r *EtherealPodReconciler) createPod(
	ctx context.Context,
	ep *sundayv1.EtherealPod,
) (*corev1.Pod, error) {

	pod := &corev1.Pod{
		ObjectMeta: metav1.ObjectMeta{
			GenerateName: ep.Name + "-",
			Namespace:    ep.Namespace,
			Labels:       ep.Spec.Template.Labels,
		},
		Spec: ep.Spec.Template.Spec,
	}

	if err := controllerutil.SetControllerReference(ep, pod, r.Scheme); err != nil {
		return nil, err
	}

	if err := r.Create(ctx, pod); err != nil {
		return nil, err
	}

	return pod, nil
}

func (r *EtherealPodReconciler) updateStatus(
	ctx context.Context,
	ep *sundayv1.EtherealPod,
	pod *corev1.Pod,
) {

	var restarts int32
	for _, cs := range pod.Status.ContainerStatuses {
		restarts += cs.RestartCount
	}

	ep.Status.PodName = pod.Name
	ep.Status.RestartCount = restarts

	_ = r.Status().Update(ctx, ep)
}

func (r *EtherealPodReconciler) SetupWithManager(mgr ctrl.Manager) error {
	return ctrl.NewControllerManagedBy(mgr).
		For(&sundayv1.EtherealPod{}).
		Owns(&corev1.Pod{}).
		Complete(r)
}
